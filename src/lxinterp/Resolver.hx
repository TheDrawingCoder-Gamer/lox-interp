package lxinterp;

using lxinterp.ArrayTools;
private enum FunctionType {
    None;
    Function;
    Method;
    Initializer;
}
private enum ClassType {
    None;
    Class;
}
class Resolver {
    private final eval:Evaluator;
    private final scopes:Array<Map<String, Bool>> = [];
    private var currentFunction = FunctionType.None;
    private var currentClass = ClassType.None;
    public function new(eval:Evaluator) {
        this.eval  = eval;
    }
    public function resolve(exprs:Array<Expr>) {
        for (expr in exprs) {
            resolveExpr(expr, false);
        }
        
    }
    function resolveExpr(expr:Expr, isInline:Bool) {
        switch (expr.type) {
            case EBlock(exprs): 
                beginScope();
                resolve(exprs);
                endScope();
            case EVar(evar): 
                declare(evar.name, expr.pos);
                if (evar.value.type != ENone) {
                    resolveExpr(evar.value, true);
                }
                define(evar.name);
            case EIdent(name):
                if (name == "this") {
                    if (currentClass == ClassType.None) {
						Lox.error(expr.pos,"Cannot use 'this' outside of a class.");
                    }
                    return;
                } 
                if (scopes.length != 0 && scopes.peek().get(name) == false) {
                    Lox.error(expr.pos, "Cannot read local variable in it's own initializer.");

                }
                resolveLocal(expr, name);
            case EClass(name, fields, _):
                var enclosingClass = currentClass;
                currentClass = Class;
                if (!isInline) {
                    declare(name, expr.pos);
                    define(name);
    
                    
                }
                beginScope();
                // Static fields are accessible from member functions
                // but member fields are not accessible from static functions
                // Thus scoping : )
				for (field in fields) {
					if (!field.access.contains(AStatic))
						continue;
					switch (field.value) {
						case FVFun(fun):
							if (field.name == "init") {
								Lox.error(expr.pos, "Init function cannot be static.");
							}
							resolveFunction(name, fun, expr.pos, Method);
						case FVVar(init):
							if (field.name == "init") {
								Lox.error(init.pos, "Classes cannot have an init var.");
							}
							declare(field.name, init.pos);
							define(field.name);
					}
				}
                beginScope();
                declare("this", expr.pos);
                define("this");
				for (field in fields) {
                    if (field.access.contains(AStatic)) continue;
					switch (field.value) {
						case FVFun(fun):
                            
                            var decl = Method;
                            if (field.name == "init") {
                                decl = Initializer;
                            }
							resolveFunction(name, fun, expr.pos, decl);
						case FVVar(init):
							if (field.name == "init") {
								Lox.error(init.pos, "Classes cannot have an init var.");
							}
                            declare(field.name, init.pos);
                            define(field.name);
					}
				}
                endScope();                
                endScope();
                currentClass = enclosingClass;
            case EAssign(name, e):
                resolveExpr(e, true);
                resolveLocal(expr, name);
            case EArrayAccess(e, index):
                resolveExpr(e, true);
                resolveExpr(index, true);
            case EFun(name, fun):
                if (!isInline) {
                    declare(name, expr.pos);
                    define(name);
                }
                resolveFunction(name, fun, expr.pos, Function);
            case EIf(econd, ethen, eelse): 
                resolveExpr(econd, true);
                resolveExpr(ethen, isInline);
                if (eelse != null) {
                    resolveExpr(eelse, isInline);
                }
            case EReturn(e):
                if (currentFunction == None) {
                    Lox.error(expr.pos, "Cannot return from top-level code.");
                }
                resolveExpr(e, true);
            case EGroup(e):
                resolveExpr(e, true);
            case EWhile(econd, ebody):
                resolveExpr(econd, true);
                resolveExpr(ebody, isInline);
            case EBinop(e1, op, e2):
                resolveExpr(e1, true);
                resolveExpr(e2, true);
            case ECall(e, args): 
                resolveExpr(e, true);
                for (arg in args) {
                    resolveExpr(arg, true);
                }
            case EField(e, field):
                resolveExpr(e, true);
            
            case EUnop(op, e):
                resolveExpr(e, true);
            case EBool(_) | ENumber(_) | EString(_) | ENone | ENil | EObjDecl(_) | EArrayDecl(_): 
                // nothing
            default: 
                // TODO
        }
    }
    function resolveLocal(expr:Expr, name:String) {
        var i = scopes.length - 1;
        while (i >= 0) {
            if (scopes[i].exists(name)) {
                eval.resolve(expr, scopes.length - i - 1);
                return;
            }
            i--;
        }
    }
    
    function resolveFunction(name:String, fun:FunDecl, pos:Position, type:FunctionType) {
        var enclosingFun = currentFunction;
        currentFunction = type;
        beginScope();
        for (param in fun.args) {
            declare(param, pos);
            define(param);
        }
        resolveExpr(fun.body, false);
        endScope();
        currentFunction = enclosingFun;
    }
    function declare(name:String, pos:Position) {
        if (scopes.length == 0) {
            return;
        }
        if (scopes.peek().exists(name)) {
            Lox.error(pos, "Variable with this name already declared in this scope.");
        }
        scopes.peek().set(name, false);
    }
    function define(name:String) {
        if (scopes.length == 0) {
            return;
        }
        scopes.peek().set(name, true);
    }
    function beginScope() {
        scopes.push(new Map<String, Bool>());
    }
    function endScope() {
        scopes.pop();
    }
}