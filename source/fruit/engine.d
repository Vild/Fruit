module fruit.engine;

import std.stdio;
import std.string;
import std.exception;
import std.datetime;

import core.thread;
import core.time;

import fruit.other.window;
import fruit.vulkan.vulkan;

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
		double time = 0;
		while (!quit) {
			window.DoEvents((ref SDL_Event e) {
				if (e.type == SDL_QUIT)
					quit = true;
				else if (e.type == SDL_KEYDOWN) {
					if (e.key.keysym.sym == SDLK_ESCAPE)
						quit = true;
				} else if (e.type == SDL_WINDOWEVENT) {
					if (e.window.event == SDL_WINDOWEVENT_RESIZED) {
						window.Size.x = e.window.data1;
						window.Size.y = e.window.data2;
						vulkan.RecreateRendering();
					} else if (e.window.event == SDL_WINDOWEVENT_HIDDEN) {
						writeln("Window minimized");
						render = false;
					} else if (e.window.event == SDL_WINDOWEVENT_EXPOSED) {
						writeln("Window restored");
						render = true;
					}

				}
			});

			immutable MonoTime curTime = MonoTime.currTime;
			immutable Duration diff = curTime - oldTime;
			immutable double delta = diff.total!"usecs" / 1_000_000.0; //1 000 000 µsec/ 1 sec
			oldTime = curTime;
			time += delta;

			{
				import gl3n.math;
				import fruit.other.linalg;

				UniformBufferObject ubo;
				ubo.model = mat4.zrotation(time * cradians!90).transposed;
				ubo.view = mat4.look_at(vec3(2.0, 2.0, 2.0), vec3(0.0, 0.0, 0.0), vec3(0.0, 0.0, 1.0)).transposed;
				ubo.proj = mat4.perspective(window.Size.x, window.Size.y, 45, 0.1f, 10.0f).transposed; // TODO: use swapChainExtent
				ubo.proj[1][1] *= -1; // Because Y is inverted

				vulkan.SetUBO(ubo);
			}

			vulkan.RenderFrame();
			fps++;

			if ((curTime - fpsTime).total!"msecs" >= 1000 / FPS_PRINTING_PER_SECOND) {
				fps *= FPS_PRINTING_PER_SECOND;
				writeln("FPS: ", (fps + oldFps) / 2.0);
				oldFps = fps;
				fps = 0;
				fpsTime += (1000 / FPS_PRINTING_PER_SECOND).msecs;
			}

			if (!render)
				Thread.sleep(100.msecs);
		}
		return 0;
	}

private:
	Window window;
	Vulkan vulkan;
	bool quit;
	bool render;

	enum FPS_PRINTING_PER_SECOND = 2;
}
