package lxinterp;

import lxinterp.Evaluator;

class Enviroment {
	final values:Map<String, Dynamic> = [];
	final enclosing:Null<Enviroment>;

	public function new(?enclosing:Enviroment) {
		this.enclosing = enclosing;
	}

	public function define(name:String, value:Dynamic = UTNone) {
		this.values[name] = value;
	}

	// Scapegoat is an expr that is attached to the assignment/lookup that is used as the position for errors.
	// Usually the identifier name.
	public function lookup(name:String, ?scapegoat:Expr):Dynamic {
		if (values.exists(name)) {
			return values[name];
		} else if (enclosing != null) {
			return enclosing.lookup(name, scapegoat);
		}
		throw new RuntimeException(scapegoat != null ? scapegoat.pos : new Position(new Point(0, 0, 0), new Point(0, 0, 0), "<unknown>"),
			"Undefined variable: " + name);
	}

	public function lookupAt(depth:Int, name:String, ?scapegoat:Expr):Dynamic {
		return ancestor(depth).lookup(name, scapegoat);
	}

	public function ancestor(depth:Int):Enviroment {
		var env:Enviroment = this;
		for (i in 0...depth) {
			env = env.enclosing;
		}
		return env;
	}

	public function assign(name:String, value:Dynamic, ?scapegoat:Expr) {
		if (values.exists(name)) {
			values[name] = value;
		} else if (enclosing != null) {
			enclosing.assign(name, value);
		} else {
			throw new RuntimeException(scapegoat != null ? scapegoat.pos : new Position(new Point(0, 0, 0), new Point(0, 0, 0), "<unknown>"),
				"Undefined variable: " + name);
		}
	}

	public function assignAt(depth:Int, name:String, value:Dynamic) {
		ancestor(depth).values.set(name, value);
	}
}
