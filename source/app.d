import fruit.engine;

int main() {
	Engine engine = new Engine();
	scope (exit)
		engine.destroy;
	return engine.Run;
}
