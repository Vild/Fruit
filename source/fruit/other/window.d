module fruit.other.window;

import std.string;
public import derelict.sdl2.sdl;
import fruit.other.linalg;

shared static this() {
	DerelictSDL2.load();
}

class Window {
public:
	this(string title, int width, int height) {
		SDL_Init(SDL_INIT_EVERYTHING);

		size = vec2u(width, height);
		window = SDL_CreateWindow(title.toStringz, SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, width, height, SDL_WINDOW_SHOWN | SDL_WINDOW_RESIZABLE);
	}

	~this() {
		SDL_DestroyWindow(window);
		SDL_Quit();
	}

	void DoEvents(void delegate(ref SDL_Event e) cb) {
		SDL_Event e;
		while (SDL_PollEvent(&e))
			cb(e);
	}

	@property SDL_Window* SDLWindow() {
		return window;
	}

	@property ref vec2u Size() {
		return size;
	}

private:
	vec2u size;

	SDL_Window* window;
}
