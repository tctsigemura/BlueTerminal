SRCS = main.swift StdioManager.swift BleManager.swift Fsm.swift
TARGET = ../bin/BlueTerminal

all: ${TARGET}

${TARGET} : x86_app arm_app
	lipo -create -output ${TARGET} x86_app arm_app

x86_app: ${SRCS}
	swiftc -o x86_app -target x86_64-apple-macos10.12 ${SRCS} # Sierra
#	swiftc -o x86_app -target x86_64-apple-macos10.15 ${SRCS} # Catalina

arm_app: ${SRCS}
	swiftc -o arm_app -target arm64-apple-macos11 ${SRCS}     # Big Sur

install:

clean:
	rm -f x86_app arm_app

