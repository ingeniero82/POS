#include "flutter_window.h"
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>
#include <winspool.h>
#include <memory>
#include <string>
#include <vector>

#pragma comment(lib, "winspool.lib")

namespace {

std::string g_selected_printer_name;
static std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> g_print_channel;

void RegisterPrintChannel(flutter::FlutterViewController* controller) {
  if (!controller || !controller->engine()) return;
  auto* messenger = controller->engine()->messenger();
  if (!messenger) return;

  g_print_channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "print_channel",
      &flutter::StandardMethodCodec::GetInstance());

  g_print_channel->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        const std::string& method = call.method_name();

        if (method == "listPrinters") {
          std::vector<flutter::EncodableValue> list;
          DWORD needed = 0, returned = 0;
          EnumPrintersW(PRINTER_ENUM_LOCAL | PRINTER_ENUM_CONNECTIONS, nullptr, 4, nullptr, 0, &needed, &returned);
          if (needed == 0) {
            result->Success(flutter::EncodableValue(list));
            return;
          }
          std::vector<BYTE> buf(needed);
          if (!EnumPrintersW(PRINTER_ENUM_LOCAL | PRINTER_ENUM_CONNECTIONS, nullptr, 4, buf.data(), needed, &needed, &returned)) {
            result->Success(flutter::EncodableValue(list));
            return;
          }
          PRINTER_INFO_4W* infos = reinterpret_cast<PRINTER_INFO_4W*>(buf.data());
          for (DWORD i = 0; i < returned; i++) {
            std::wstring nameW(infos[i].pPrinterName);
            int len = WideCharToMultiByte(CP_UTF8, 0, nameW.c_str(), -1, nullptr, 0, nullptr, nullptr);
            std::string name(len > 0 ? len - 1 : 0, '\0');
            if (len > 0) WideCharToMultiByte(CP_UTF8, 0, nameW.c_str(), -1, &name[0], len, nullptr, nullptr);
            std::map<flutter::EncodableValue, flutter::EncodableValue> m;
            m[flutter::EncodableValue("name")] = flutter::EncodableValue(name);
            list.push_back(flutter::EncodableValue(m));
          }
          result->Success(flutter::EncodableValue(list));
          return;
        }

        if (method == "connectToPrinterByName") {
          const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
          if (args) {
            auto it = args->find(flutter::EncodableValue("name"));
            if (it != args->end()) {
              const auto* name = std::get_if<std::string>(&it->second);
              if (name && !name->empty()) {
                g_selected_printer_name = *name;
                result->Success(flutter::EncodableValue(true));
                return;
              }
            }
          }
          result->Success(flutter::EncodableValue(false));
          return;
        }

        if (method == "printRaw") {
          const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
          std::string printer_name = g_selected_printer_name;
          if (args) {
            auto it = args->find(flutter::EncodableValue("printerName"));
            if (it != args->end()) {
              const auto* pn = std::get_if<std::string>(&it->second);
              if (pn && !pn->empty()) printer_name = *pn;
            }
          }
          if (printer_name.empty()) {
            result->Success(flutter::EncodableValue(false));
            return;
          }
          int wlen = MultiByteToWideChar(CP_UTF8, 0, printer_name.c_str(), -1, nullptr, 0);
          std::wstring wname(wlen > 0 ? wlen - 1 : 0, L'\0');
          if (wlen > 0) MultiByteToWideChar(CP_UTF8, 0, printer_name.c_str(), -1, &wname[0], wlen);
          HANDLE hPrinter = nullptr;
          if (!OpenPrinterW(const_cast<LPWSTR>(wname.c_str()), &hPrinter, nullptr)) {
            result->Success(flutter::EncodableValue(false));
            return;
          }
          const std::vector<uint8_t>* data_arg = nullptr;
          if (args) {
            auto it = args->find(flutter::EncodableValue("data"));
            if (it != args->end()) {
              data_arg = std::get_if<std::vector<uint8_t>>(&it->second);
            }
          }
          if (!data_arg || data_arg->empty()) {
            ClosePrinter(hPrinter);
            result->Success(flutter::EncodableValue(true));
            return;
          }
          DOC_INFO_1W docInfo = {};
          docInfo.pDocName = L"POS Receipt";
          docInfo.pOutputFile = nullptr;
          docInfo.pDatatype = L"RAW";
          if (StartDocPrinterW(hPrinter, 1, reinterpret_cast<LPBYTE>(&docInfo)) <= 0) {
            ClosePrinter(hPrinter);
            result->Success(flutter::EncodableValue(false));
            return;
          }
          if (!StartPagePrinter(hPrinter)) {
            EndDocPrinter(hPrinter);
            ClosePrinter(hPrinter);
            result->Success(flutter::EncodableValue(false));
            return;
          }
          DWORD written = 0;
          BOOL ok = WritePrinter(hPrinter, const_cast<void*>(static_cast<const void*>(data_arg->data())), static_cast<DWORD>(data_arg->size()), &written);
          EndPagePrinter(hPrinter);
          EndDocPrinter(hPrinter);
          ClosePrinter(hPrinter);
          result->Success(flutter::EncodableValue(ok && written == data_arg->size()));
          return;
        }

        if (method == "connectUSB" || method == "connectSerial" || method == "disconnect") {
          result->NotImplemented();
          return;
        }

        result->NotImplemented();
      });
}

}  // namespace

void RegisterPrintChannelWithController(flutter::FlutterViewController* controller) {
  RegisterPrintChannel(controller);
}
