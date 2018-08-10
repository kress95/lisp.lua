default:
	parlinter lisp.lisp --trim --write
	luajit init.lua && luajit lisp.lua

.PHONY: default
