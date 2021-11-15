package lxinterp;

interface LoxCallable {
	function arity():Int;
	function call(eval:Evaluator, args:Array<Dynamic>):Dynamic;
}
