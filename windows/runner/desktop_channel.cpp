#include "desktop_channel.h"
#include <shellapi.h>
#include <shlobj.h>
#include <shlwapi.h>
#include <wrl/client.h>
#include <cstring>
#include <string>
#include <vector>

namespace {
using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;
using Microsoft::WRL::ComPtr;

std::wstring LocalPath(const EncodableValue& value) {
  const auto* text = std::get_if<std::string>(&value);
  if (!text || text->empty() || text->find('\0') != std::string::npos) return {};
  const int size = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text->data(),
                                      static_cast<int>(text->size()), nullptr, 0);
  if (size <= 0) return {};
  std::wstring path(size, L'\0');
  MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text->data(),
                     static_cast<int>(text->size()), path.data(), size);
  if (PathIsRelativeW(path.c_str()) || GetFileAttributesW(path.c_str()) == INVALID_FILE_ATTRIBUTES) return {};
  return path;
}

// CF_HDROP is the standard Explorer file-list payload. No file is moved here;
// the target performs the copy after a successful drop.
HRESULT FilePayload(const EncodableList& values, IDataObject** output) {
  if (values.empty()) return E_INVALIDARG;
  std::vector<std::wstring> paths;
  size_t characters = 1;
  for (const auto& value : values) {
    auto path = LocalPath(value);
    if (path.empty()) return E_INVALIDARG;
    characters += path.size() + 1;
    paths.push_back(std::move(path));
  }
  ComPtr<IDataObject> data;
  HRESULT hr = SHCreateDataObject(nullptr, 0, nullptr, nullptr, IID_PPV_ARGS(&data));
  if (FAILED(hr)) return hr;
  const size_t bytes = sizeof(DROPFILES) + characters * sizeof(wchar_t);
  HGLOBAL memory = GlobalAlloc(GMEM_MOVEABLE | GMEM_ZEROINIT, bytes);
  if (!memory) return E_OUTOFMEMORY;
  auto* drop = static_cast<DROPFILES*>(GlobalLock(memory));
  if (!drop) { GlobalFree(memory); return E_OUTOFMEMORY; }
  drop->pFiles = sizeof(DROPFILES);
  drop->fWide = TRUE;
  auto* destination = reinterpret_cast<wchar_t*>(drop + 1);
  for (const auto& path : paths) {
    const size_t length = path.size() + 1;
    std::memcpy(destination, path.c_str(), length * sizeof(wchar_t));
    destination += length;
  }
  GlobalUnlock(memory);
  FORMATETC format{CF_HDROP, nullptr, DVASPECT_CONTENT, -1, TYMED_HGLOBAL};
  STGMEDIUM medium{};
  medium.tymed = TYMED_HGLOBAL;
  medium.hGlobal = memory;
  hr = data->SetData(&format, &medium, TRUE);
  if (FAILED(hr)) { GlobalFree(memory); return hr; }
  *output = data.Detach();
  return S_OK;
}
}  // namespace

std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
CreateDesktopChannel(flutter::BinaryMessenger* messenger, HWND window) {
  auto channel = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      messenger, "canvas_quiz_exporter/windows", &flutter::StandardMethodCodec::GetInstance());
  channel->SetMethodCallHandler([window](const auto& call, auto result) {
    if (call.method_name() == "processAgeMs") {
      FILETIME created{}, exited{}, kernel{}, user{}, now{};
      GetProcessTimes(GetCurrentProcess(), &created, &exited, &kernel, &user);
      GetSystemTimeAsFileTime(&now);
      ULARGE_INTEGER begin{}, end{};
      begin.LowPart = created.dwLowDateTime; begin.HighPart = created.dwHighDateTime;
      end.LowPart = now.dwLowDateTime; end.HighPart = now.dwHighDateTime;
      result->Success(EncodableValue(static_cast<int64_t>((end.QuadPart - begin.QuadPart) / 10000)));
      return;
    }
    if (call.method_name() == "capabilities") {
      result->Success(EncodableValue(EncodableMap{
          {EncodableValue("openPath"), EncodableValue(true)},
          {EncodableValue("dragFiles"), EncodableValue(true)}}));
      return;
    }
    if (call.method_name() == "openPath") {
      const auto path = call.arguments() ? LocalPath(*call.arguments()) : std::wstring();
      if (path.empty()) { result->Error("invalid_path", "The file or folder no longer exists."); return; }
      const auto code = reinterpret_cast<INT_PTR>(ShellExecuteW(window, L"open", path.c_str(), nullptr, nullptr, SW_SHOWNORMAL));
      if (code <= 32) { result->Error("open_failed", "Windows could not open this item."); return; }
      result->Success();
      return;
    }
    if (call.method_name() == "dragFiles" || call.method_name() == "verifyDragPayload") {
      const auto* values = call.arguments() ? std::get_if<EncodableList>(call.arguments()) : nullptr;
      ComPtr<IDataObject> data;
      if (!values || FAILED(FilePayload(*values, &data))) {
        result->Error("invalid_files", "The drag payload contains a missing or invalid file."); return;
      }
      if (call.method_name() == "verifyDragPayload") {
        FORMATETC format{CF_HDROP, nullptr, DVASPECT_CONTENT, -1, TYMED_HGLOBAL};
        STGMEDIUM medium{};
        if (FAILED(data->GetData(&format, &medium))) { result->Error("payload_failed", "Cannot read file payload."); return; }
        const auto count = DragQueryFileW(static_cast<HDROP>(medium.hGlobal), 0xFFFFFFFF, nullptr, 0);
        ReleaseStgMedium(&medium);
        result->Success(EncodableValue(static_cast<int>(count)));
        return;
      }
      DWORD effect = DROPEFFECT_NONE;
      const HRESULT hr = SHDoDragDrop(window, data.Get(), nullptr, DROPEFFECT_COPY, &effect);
      if (FAILED(hr)) result->Error("drag_failed", "Windows could not start the file drag.");
      else result->Success();
      return;
    }
    result->NotImplemented();
  });
  return channel;
}
