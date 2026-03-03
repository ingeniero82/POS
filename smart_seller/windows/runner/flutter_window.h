#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>

#include <memory>
#include <string>

#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;
  
  // Print service members
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> print_channel_;
  bool is_printer_connected_ = false;
  std::string current_printer_port_;
  HANDLE serial_handle_ = INVALID_HANDLE_VALUE;
  
  // Print service methods
  void RegisterPrintChannel();
  void HandleConnectUSB(const flutter::MethodCall<flutter::EncodableValue>& call,
                       std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleConnectSerial(const flutter::MethodCall<flutter::EncodableValue>& call,
                          std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandlePrintRaw(const flutter::MethodCall<flutter::EncodableValue>& call,
                     std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleDisconnect(const flutter::MethodCall<flutter::EncodableValue>& call,
                       std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleCheckStatus(const flutter::MethodCall<flutter::EncodableValue>& call,
                        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleListPrinters(const flutter::MethodCall<flutter::EncodableValue>& call,
                         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  bool ConnectToSerialPort(const std::string& port);
  bool PrintToUSB(const std::vector<uint8_t>& data);
  bool PrintToSerial(const std::vector<uint8_t>& data);
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
