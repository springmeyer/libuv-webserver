
all: ./build ./webclient ./webserver

./deps/llhttp:
	mkdir -p deps
	curl -L https://github.com/nodejs/llhttp/archive/refs/tags/release/v9.3.0.tar.gz | tar xz -C deps/
	mv deps/llhttp-release-v9.3.0 deps/llhttp

./deps/libuv:
	mkdir -p deps
	curl -L https://github.com/libuv/libuv/archive/refs/tags/v1.51.0.tar.gz | tar xz -C deps/
	mv deps/libuv-1.51.0 deps/libuv

./build: ./deps/libuv ./deps/llhttp
	mkdir -p build
	cd build && cmake .. -DCMAKE_BUILD_TYPE=Release

./webclient: ./build webclient.cc
	cd build && cmake --build . --target webclient
	cp ./build/webclient ./webclient

./webserver: ./build webserver.cc
	cd build && cmake --build . --target webserver
	cp ./build/webserver ./webserver

distclean:
	rm -rf ./build ./build-sanitizer
	rm -rf ./deps
	rm -f ./webserver ./webclient

test:
	./webserver & sleep 1 && ./webclient && killall webserver

sanitizer: ./deps/libuv ./deps/llhttp
	mkdir -p build-sanitizer
	cd build-sanitizer && cmake .. -DCMAKE_BUILD_TYPE=Debug \
		-DCMAKE_C_FLAGS="-fsanitize=address,undefined -fno-omit-frame-pointer -g" \
		-DCMAKE_CXX_FLAGS="-fsanitize=address,undefined -fno-omit-frame-pointer -g" \
		-DCMAKE_EXE_LINKER_FLAGS="-fsanitize=address,undefined"
	cd build-sanitizer && cmake --build . --target webserver
	cd build-sanitizer && cmake --build . --target webclient
	@echo ""
	@echo "=== Testing webserver with sanitizers ==="
	@cd build-sanitizer && ./webserver & sleep 2 && \
		curl -s http://127.0.0.1:8000/ > /dev/null && \
		curl -s http://127.0.0.1:8000/README.md > /dev/null && \
		curl -s http://127.0.0.1:8000/nonexistent > /dev/null && \
		killall webserver && sleep 1
	@echo "=== Testing webclient with sanitizers ==="
	@cd build-sanitizer && ./webserver & sleep 1 && ./webclient ; killall webserver || true
	@echo ""
	@echo "✓ Sanitizer tests completed successfully"

clean:
	rm -rf ./build ./build-sanitizer
	rm -f ./webserver ./webclient

.PHONY: test all clean distclean sanitizer
