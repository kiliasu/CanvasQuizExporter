#ifndef RUNNER_DESKTOP_CHANNEL_H_
#define RUNNER_DESKTOP_CHANNEL_H_
#include <windows.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <memory>

std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
CreateDesktopChannel(flutter::BinaryMessenger* messenger, HWND window);
#endif
