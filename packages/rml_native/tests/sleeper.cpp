#if defined(_WIN32)
	#include <Windows.h>

static LRESULT CALLBACK window_procedure(const HWND window, const UINT message, const WPARAM wparam, const LPARAM lparam)
{
	if (message == WM_DESTROY)
	{
		PostQuitMessage(0);
		return 0;
	}
	return DefWindowProcW(window, message, wparam, lparam);
}

int main()
{
	WNDCLASSW window_class{};
	window_class.lpfnWndProc = window_procedure;
	window_class.hInstance = GetModuleHandleW(nullptr);
	window_class.lpszClassName = L"RmlSleeper";
	RegisterClassW(&window_class);
	CreateWindowExW(0,
	    window_class.lpszClassName,
	    L"rml sleeper",
	    WS_OVERLAPPEDWINDOW,
	    CW_USEDEFAULT,
	    CW_USEDEFAULT,
	    100,
	    100,
	    nullptr,
	    nullptr,
	    window_class.hInstance,
	    nullptr);
	MSG message{};
	while (GetMessageW(&message, nullptr, 0, 0) > 0)
	{
		TranslateMessage(&message);
		DispatchMessageW(&message);
	}
	return 0;
}
#else
	#include <chrono>
	#include <thread>

int main()
{
	std::this_thread::sleep_for(std::chrono::seconds(60));
	return 0;
}
#endif
