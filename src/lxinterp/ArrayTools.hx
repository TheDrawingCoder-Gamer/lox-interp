package lxinterp;

class ArrayTools {
	public static function peek<T>(arr:Array<T>):T {
		return arr[arr.length - 1];
	}
}
