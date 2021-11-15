package lxinterp;

import lxinterp.Evaluator.RuntimeException;

class LoxInstance implements LoxHasMembers {
	private var klass:LoxClass;
	// Fields meaning only vars. Functions that don't have Dynamic metadata are called from the class itself.
	private var fields:Map<String, Dynamic> = [];

	public function new(klass:LoxClass) {
		this.klass = klass;
	}

	public function get(name:String):Dynamic {
		if (fields.exists(name)) {
			return fields.get(name);
		}
		var classStandin = klass.findField(name);
		if (classStandin == null) {
			throw new RuntimeException(new Position(new Point(0, 0, 0), new Point(0, 0, 0), "<unknown>"), "Undefined property '" + name + "'.");
		}
		if (classStandin.access.contains(AStatic)) {
			Lox.error(new Position(new Point(0, 0, 0), new Point(0, 0, 0), "<unknown>"), "Cannot access static member '" + name + "' from instance.");
			return UTNone;
		}

		switch (classStandin.value) {
			case RFVFun(fun):
				if (classStandin.access.contains(ADynamic)) {
					fields.set(name, fun);
				}
				return fun.bind(this);
			case RFVVar(init):
				fields.set(name, init);
				return init;
		}
	}

	public function set(name:String, value:Dynamic) {
		if (fields.exists(name)) {
			// Should always work? TODO make sure this isn't stupid
			fields.set(name, value);
		} else {
			var classStandin = klass.findField(name);
			if (classStandin.access.contains(AStatic))
				Lox.error(new Position(new Point(0, 0, 0), new Point(0, 0, 0), "<unknown>"), "Cannot access static member '" + name + "' from instance.");
			switch (classStandin.value) {
				case RFVVar(init):
					fields.set(name, value);
				case RFVFun(fun):
					if (classStandin.access.contains(ADynamic)) {
						fields.set(name, value);
					} else {
						Lox.error(new Position(new Point(0, 0, 0), new Point(0, 0, 0), "<unknown>"), "Cannot assign to function '" + name + "'.");
					}
			}
		}
	}
}

// Using the terminology wrong here.
// This just means the class singleton that is used for static.
class LoxMetaclass extends LoxInstance implements LoxHasMembers {
	public function new(klass:LoxClass) {
		super(klass);
	}

	public override function get(name:String):Dynamic {
		if (fields.exists(name)) {
			return fields.get(name);
		}
		var classStandin = klass.findField(name);
		if (classStandin.access.contains(AStatic)) {
			switch (classStandin.value) {
				case RFVFun(fun):
					if (classStandin.access.contains(ADynamic))
						this.fields.set(name, fun);
					return fun;
				case RFVVar(init):
					this.fields.set(name, init);
					return init;
			}
		}
		Lox.error(new Position(new Point(0, 0, 0), new Point(0, 0, 0), "<unknown>"), "Cannot access member '" + name + "' from class.");
		return UTNone;
	}

	public override function set(name:String, value:Dynamic) {
		var klassField = klass.findField(name);
		if (klassField.access.contains(AStatic)) {
			switch (klassField.value) {
				case RFVVar(init):
					fields.set(name, value);
				case RFVFun(fun):
					if (klassField.access.contains(ADynamic)) {
						fields.set(name, value);
					} else {
						Lox.error(new Position(new Point(0, 0, 0), new Point(0, 0, 0), "<unknown>"), "Cannot assign to function '" + name + "'.");
					}
			}
		} else {
			Lox.error(new Position(new Point(0, 0, 0), new Point(0, 0, 0), "<unknown>"), "Cannot assign to member '" + name + "' from class.");
		}
	}
}
