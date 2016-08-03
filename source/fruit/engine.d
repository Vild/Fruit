module fruit.engine;

import std.string;
import std.exception;
import std.datetime;

import core.thread;
import core.time;

import fruit.window;
import fruit.vulkan;

class Engine {
public:
	this() {
		window = new Window("Fruit", 1920, 1080);
		vulkan = new Vulkan("Fruit", 1, 0, 0, window);
	}

	~this() {
		vulkan.destroy;
		window.destroy;
	}

	int Run() {
		MonoTime oldTime = MonoTime.currTime;
		MonoTime fpsTime = MonoTime.currTime;
		ulong fps;
		ulong oldFps;
		while (!quit) {
			window.DoEvents((ref SDL_Event e) {
				if (e.type == SDL_QUIT)
					quit = true;
				else if (e.type == SDL_KEYDOWN) {
					if (e.key.keysym.sym == SDLK_ESCAPE)
						quit = true;
				} else if (e.type == SDL_WINDOWEVENT) {
					if (e.window.event == SDL_WINDOWEVENT_RESIZED) {
						import fruit.linalg;
						window.Size = vec2u(e.window.data1, e.window.data2);
						vulkan.RecreateRendering();
					}
				}
			});

			immutable MonoTime curTime = MonoTime.currTime;
			immutable Duration diff = curTime - oldTime;
			immutable double delta = diff.total!"usecs" / 1_000_000; //1 000 000 µsec/ 1 sec
			oldTime = curTime;

			vulkan.RenderFrame();
			fps++;

			if ((curTime - fpsTime).total!"msecs" >= 1000 / FPS_PRINTING_PER_SECOND) {
				import std.stdio;

				fps *= FPS_PRINTING_PER_SECOND;
				writeln("FPS: ", (fps + oldFps) / 2.0);
				oldFps = fps;
				fps = 0;
				fpsTime += (1000 / FPS_PRINTING_PER_SECOND).msecs;
			}
		}
		return 0;
	}

private:
	Window window;
	Vulkan vulkan;
	bool quit;

	enum FPS_PRINTING_PER_SECOND = 2;
}
