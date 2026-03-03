#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"

// Agregar para el canal de impresión
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>
#include <winspool.h>

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  
  // Registrar el canal de impresión
  RegisterPrintChannel();
  
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::RegisterPrintChannel() {
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "print_channel",
      &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler([this](const flutter::MethodCall<flutter::EncodableValue>& call,
                                     std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    if (call.method_name().compare("connectUSB") == 0) {
      HandleConnectUSB(call, std::move(result));
    } else if (call.method_name().compare("connectSerial") == 0) {
      HandleConnectSerial(call, std::move(result));
    } else if (call.method_name().compare("printRaw") == 0) {
      HandlePrintRaw(call, std::move(result));
    } else if (call.method_name().compare("disconnect") == 0) {
      HandleDisconnect(call, std::move(result));
    } else if (call.method_name().compare("checkStatus") == 0) {
      HandleCheckStatus(call, std::move(result));
    } else if (call.method_name().compare("listPrinters") == 0) {
      HandleListPrinters(call, std::move(result));
    } else {
      result->NotImplemented();
    }
  });

  print_channel_ = std::move(channel);
}

void FlutterWindow::HandleConnectUSB(const flutter::MethodCall<flutter::EncodableValue>& call,
                                   std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  // Buscar impresora Citizen en el sistema
  bool found = false;
  
  // Enumerar impresoras instaladas
  DWORD needed, returned;
  EnumPrinters(PRINTER_ENUM_LOCAL | PRINTER_ENUM_CONNECTIONS, NULL, 2, NULL, 0, &needed, &returned);
  
  if (needed > 0) {
    LPBYTE buffer = new BYTE[needed];
    if (EnumPrinters(PRINTER_ENUM_LOCAL | PRINTER_ENUM_CONNECTIONS, NULL, 2, buffer, needed, &needed, &returned)) {
      PRINTER_INFO_2* printers = (PRINTER_INFO_2*)buffer;
      
      for (DWORD i = 0; i < returned; i++) {
        std::wstring printerName(printers[i].pPrinterName);
        std::string printerNameStr(printerName.begin(), printerName.end());
        
        // Buscar impresoras Citizen
        if (printerNameStr.find("Citizen") != std::string::npos || 
            printerNameStr.find("TZ30") != std::string::npos ||
            printerNameStr.find("CT-S") != std::string::npos) {
          found = true;
          is_printer_connected_ = true;
          current_printer_port_ = "USB_" + printerNameStr;
          break;
        }
      }
    }
    delete[] buffer;
  }
  
  result->Success(flutter::EncodableValue(found));
}

void FlutterWindow::HandleConnectSerial(const flutter::MethodCall<flutter::EncodableValue>& call,
                                      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  // Obtener parámetros del puerto serie
  const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
  if (!arguments) {
    result->Error("INVALID_ARGUMENTS", "Arguments must be a map");
    return;
  }

  const auto port_it = arguments->find(flutter::EncodableValue("port"));
  if (port_it == arguments->end()) {
    result->Error("MISSING_PORT", "Port parameter is required");
    return;
  }

  const auto port_value = std::get_if<std::string>(&port_it->second);
  if (!port_value) {
    result->Error("INVALID_PORT", "Port must be a string");
    return;
  }

  // Intentar conectar al puerto serie
  bool connected = ConnectToSerialPort(*port_value);
  
  if (connected) {
    is_printer_connected_ = true;
    current_printer_port_ = *port_value;
  }
  
  result->Success(flutter::EncodableValue(connected));
}

bool FlutterWindow::ConnectToSerialPort(const std::string& port) {
  // Crear handle para el puerto serie
  std::string fullPortName = "\\\\.\\" + port;
  
  // Convertir string a wstring para la API de Windows
  std::wstring widePortName(fullPortName.begin(), fullPortName.end());
  
  serial_handle_ = CreateFile(widePortName.c_str(),
                             GENERIC_READ | GENERIC_WRITE,
                             0,
                             NULL,
                             OPEN_EXISTING,
                             FILE_ATTRIBUTE_NORMAL,
                             NULL);
  
  if (serial_handle_ == INVALID_HANDLE_VALUE) {
    return false;
  }

  // Configurar parámetros del puerto serie
  DCB dcb = {0};
  dcb.DCBlength = sizeof(DCB);
  
  if (!GetCommState(serial_handle_, &dcb)) {
    CloseHandle(serial_handle_);
    serial_handle_ = INVALID_HANDLE_VALUE;
    return false;
  }

  dcb.BaudRate = CBR_9600;
  dcb.ByteSize = 8;
  dcb.Parity = NOPARITY;
  dcb.StopBits = ONESTOPBIT;
  
  if (!SetCommState(serial_handle_, &dcb)) {
    CloseHandle(serial_handle_);
    serial_handle_ = INVALID_HANDLE_VALUE;
    return false;
  }

  // Configurar timeouts
  COMMTIMEOUTS timeouts = {0};
  timeouts.ReadIntervalTimeout = 50;
  timeouts.ReadTotalTimeoutConstant = 50;
  timeouts.ReadTotalTimeoutMultiplier = 10;
  timeouts.WriteTotalTimeoutConstant = 50;
  timeouts.WriteTotalTimeoutMultiplier = 10;
  
  if (!SetCommTimeouts(serial_handle_, &timeouts)) {
    CloseHandle(serial_handle_);
    serial_handle_ = INVALID_HANDLE_VALUE;
    return false;
  }

  return true;
}

void FlutterWindow::HandlePrintRaw(const flutter::MethodCall<flutter::EncodableValue>& call,
                                 std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!is_printer_connected_) {
    result->Error("NOT_CONNECTED", "Printer is not connected");
    return;
  }

  const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
  if (!arguments) {
    result->Error("INVALID_ARGUMENTS", "Arguments must be a map");
    return;
  }

  const auto data_it = arguments->find(flutter::EncodableValue("data"));
  if (data_it == arguments->end()) {
    result->Error("MISSING_DATA", "Data parameter is required");
    return;
  }

  const auto data_value = std::get_if<std::vector<uint8_t>>(&data_it->second);
  if (!data_value) {
    result->Error("INVALID_DATA", "Data must be a byte array");
    return;
  }

  // Enviar datos a la impresora
  bool success = false;
  
  if (current_printer_port_.find("USB_") == 0) {
    success = PrintToUSB(*data_value);
  } else if (current_printer_port_ == "SIMULATION") {
    success = true; // Simular éxito para desarrollo
  } else {
    success = PrintToSerial(*data_value);
  }
  
  result->Success(flutter::EncodableValue(success));
}

bool FlutterWindow::PrintToUSB(const std::vector<uint8_t>& data) {
  // Usar la impresora Citizen detectada
  HANDLE printer_handle;
  
  // Extraer el nombre de la impresora del puerto
  std::string printerName = current_printer_port_.substr(4); // Quitar "USB_"
  std::wstring widePrinterName(printerName.begin(), printerName.end());
  
  if (!OpenPrinter(const_cast<LPWSTR>(widePrinterName.c_str()), &printer_handle, NULL)) {
    return false;
  }

  DOC_INFO_1 doc_info;
  doc_info.pDocName = L"Smart Seller Receipt";
  doc_info.pOutputFile = NULL;
  doc_info.pDatatype = L"RAW";

  DWORD job_id = StartDocPrinter(printer_handle, 1, (LPBYTE)&doc_info);
  if (job_id == 0) {
    ClosePrinter(printer_handle);
    return false;
  }

  if (!StartPagePrinter(printer_handle)) {
    EndDocPrinter(printer_handle);
    ClosePrinter(printer_handle);
    return false;
  }

  DWORD bytes_written;
  bool success = WritePrinter(printer_handle, (LPVOID)data.data(), static_cast<DWORD>(data.size()), &bytes_written);

  EndPagePrinter(printer_handle);
  EndDocPrinter(printer_handle);
  ClosePrinter(printer_handle);

  return success && (bytes_written == static_cast<DWORD>(data.size()));
}

bool FlutterWindow::PrintToSerial(const std::vector<uint8_t>& data) {
  if (serial_handle_ == INVALID_HANDLE_VALUE) {
    return false;
  }

  DWORD bytes_written;
  bool success = WriteFile(serial_handle_, data.data(), static_cast<DWORD>(data.size()), &bytes_written, NULL);
  
  return success && (bytes_written == static_cast<DWORD>(data.size()));
}

void FlutterWindow::HandleDisconnect(const flutter::MethodCall<flutter::EncodableValue>& call,
                                   std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (serial_handle_ != INVALID_HANDLE_VALUE) {
    CloseHandle(serial_handle_);
    serial_handle_ = INVALID_HANDLE_VALUE;
  }
  
  is_printer_connected_ = false;
  current_printer_port_ = "";
  
  result->Success(flutter::EncodableValue(true));
}

void FlutterWindow::HandleCheckStatus(const flutter::MethodCall<flutter::EncodableValue>& call,
                                    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->Success(flutter::EncodableValue(is_printer_connected_));
}

void FlutterWindow::HandleListPrinters(const flutter::MethodCall<flutter::EncodableValue>& call,
                                      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  flutter::EncodableList printerList;
  
  // Enumerar impresoras instaladas
  DWORD needed, returned;
  EnumPrinters(PRINTER_ENUM_LOCAL | PRINTER_ENUM_CONNECTIONS, NULL, 2, NULL, 0, &needed, &returned);
  
  if (needed > 0) {
    LPBYTE buffer = new BYTE[needed];
    if (EnumPrinters(PRINTER_ENUM_LOCAL | PRINTER_ENUM_CONNECTIONS, NULL, 2, buffer, needed, &needed, &returned)) {
      PRINTER_INFO_2* printers = (PRINTER_INFO_2*)buffer;
      
      for (DWORD i = 0; i < returned; i++) {
        std::wstring printerName(printers[i].pPrinterName);
        std::string printerNameStr(printerName.begin(), printerName.end());
        
        flutter::EncodableMap printerInfo;
        printerInfo[flutter::EncodableValue("name")] = flutter::EncodableValue(printerNameStr);
        printerInfo[flutter::EncodableValue("isCitizen")] = flutter::EncodableValue(
          printerNameStr.find("Citizen") != std::string::npos || 
          printerNameStr.find("TZ30") != std::string::npos ||
          printerNameStr.find("CT-S") != std::string::npos
        );
        
        printerList.push_back(flutter::EncodableValue(printerInfo));
      }
    }
    delete[] buffer;
  }
  
  result->Success(flutter::EncodableValue(printerList));
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }
  
  // Limpiar recursos de impresión
  if (serial_handle_ != INVALID_HANDLE_VALUE) {
    CloseHandle(serial_handle_);
    serial_handle_ = INVALID_HANDLE_VALUE;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                             WPARAM const wparam,
                             LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
