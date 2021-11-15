package lxinterp;

class LoxObject implements LoxHasMembers {
	final members:Map<String, Dynamic> = [];

	public function new(members:Map<String, Dynamic>) {
		this.members = members;
	}

	public function get(name:String):Dynamic {
		return this.members.exists(name) ? this.members[name] : UTNone;
	}

	public function set(name:String, value:Dynamic):Void {
		this.members[name] = value;
	}

	public function toString():String {
		var string = '#{';
		for (key => value in members) {
			string += key + ' : ' + Evaluator.stringify(value) + ',';
		}
		// Remove last comma
		string = string.substring(0, string.length - 1);
		string += '}';
		return string;
	}
}
