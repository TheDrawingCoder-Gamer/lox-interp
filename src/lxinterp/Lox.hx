package lxinterp;

import sys.FileSystem;

class Lox {
	public static var hadError = false;
	public static final stdpath = "./std";

	public static function main() {
		var args = Sys.args();
		if (args.length == 0) {
			Lox.runPrompt();
		} else if (args.length == 1) {
			Lox.runFile(args[0]);
		} else {
			Sys.println("Usage: lox [script]");
			Sys.exit(64);
		}
	}

	static function runPrompt() {
		var input = Sys.stdin();
		while (true) {
			Sys.print("> ");
			var line = input.readLine();
			if (line == "") {
				break;
			}
			run(line);
			if (hadError)
				hadError = false;
		}
	}

	static function runFile(path) {
		var file:Null<String> = null;
		try {
			file = sys.io.File.getContent(path);
		} catch (e) {}
		if (file == null) {
			Sys.println("Could not open file '" + path + "'");
			Sys.exit(65);
		}

		run(file, FileSystem.absolutePath(path));
		if (hadError)
			Sys.exit(65);
	}

	public static function run(src:String, ?fileName = "<unknown>") {
		var lexer = new Lexer(src, fileName);
		var tokens = lexer.tokenize();
		/*
			for (token in tokens) {
				Sys.println(token);
		}*/
		var parser = new Parser(tokens);
		var exprs = parser.parse();

		if (hadError)
			return null;
		/*
			for (expr in exprs) {
				Sys.println(expr);
			} 
		 */
		var eval = new Evaluator(exprs, fileName);
		var resolver = new Resolver(eval);
		resolver.resolve(exprs);
		if (hadError)
			return null;
		eval.execute();
		return eval;
	}

	public static function error(pos:Position, msg:String) {
		report(pos, msg);
	}

	static function report(pos:Position, msg:String) {
		hadError = true;
		Sys.stderr().writeString("Error at " + pos.toString() + ": " + msg + '\n');
	}
}
