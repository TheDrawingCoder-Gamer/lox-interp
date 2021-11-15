package lxinterp;

class StdFunction implements LoxCallable {
    public static final loxPrint:StdFunction = new StdFunction(1, (_, args) -> {Sys.println(args[0]); return UTNone;});
    final alias:(Evaluator, Array<Dynamic>) -> Dynamic;
    final arityCount:Int;
    public function new(arity:Int, fun:(Evaluator, Array<Dynamic>) -> Dynamic) {
        this.alias = fun;
        this.arityCount = arity;
    }
    public function call(eval:Evaluator, args:Array<Dynamic>) {
        return this.alias(eval, args);
        return UTNone;
    }
    public function arity() {
        return arityCount;
    }
}