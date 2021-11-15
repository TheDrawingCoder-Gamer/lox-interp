package lxinterp;

import lxinterp.LoxFunction;

enum ExprType {
	EBool(bool:Bool);
	ENumber(num:Float);
	EString(str:String);
	ENil;
	// EThis;
	EIdent(name:String);
	EGroup(expr:Expr);
	EBinop(left:Expr, op:Binop, right:Expr);
	EUnop(op:Unop, e:Expr);
	EField(e:Expr, field:String);
	EFieldSet(e:Expr, field:String, value:Expr);
	ECall(e:Expr, args:Array<Expr>);
	EAssign(name:String, e:Expr);
	EArrayDecl(items:Array<Expr>);
	EObjDecl(fields:Array<Var>);
	EIf(econd:Expr, ethen:Expr, eelse:Expr);
	EVar(evar:Var);
	EBlock(exprs:Array<Expr>);
	EWhile(econd:Expr, ebody:Expr);
	EFun(name:String, fun:FunDecl);
	EReturn(value:Expr);
	EClass(name:String, fields:Array<ClassField>, ?superclass:String);
	ESuper(name:String);
	EArrayAccess(e:Expr, index:Expr);
	ENone;
	EImport(id:String, from:String);
	EExport(evarname:String);
}

enum UnitType {
	UTNone;
}

enum AccessModifier {
	APublic;
	APrivate;
	ADynamic;
	AStatic;
	AOverride;
}

enum Binop {
	BAdd;
	BSub;
	BMul;
	BDiv;
	BEqual;
	BNotEqual;
	BLess;
	BLessEqual;
	BGreater;
	BGreaterEqual;
	BAnd;
	BOr;
}

enum Unop {
	UNot;
	UNegate;
}

@:structInit
class Expr {
	public final type:ExprType;
	public final pos:Position;

	public function new(type:ExprType, pos:Position) {
		this.type = type;
		this.pos = pos;
	}

	public function toString():String {
		return "Expr(" + this.type + ")";
	}
}

typedef Var = {
	var name:String;
	var value:Expr;
}

typedef ClassField = {
	var access:Array<AccessModifier>;
	var name:String;
	var value:FieldValue;
}

typedef RealClassField = {
	var access:Array<AccessModifier>;
	var name:String;
	var value:RealFieldValue;
}

enum RealFieldValue {
	RFVVar(init:Dynamic);
	RFVFun(fun:LoxFunction);
}

enum FieldValue {
	FVVar(?init:Expr);
	FVFun(fun:FunDecl);
}

typedef FunDecl = {
	var args:Array<String>;
	var body:Expr;
}
