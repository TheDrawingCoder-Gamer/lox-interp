package lxinterp;

import lxinterp.Expr;

class Parser {
	final tokens:Array<Token>;
	var current:Int = 0;

	public function new(tokens:Array<Token>) {
		this.tokens = tokens;
	}

	public function parse():Array<Expr> {
		try {
			var exprs = [];
			while (!isAtEnd()) {
				var expr:Expr = expression(false);
				switch (expr.type) {
					// These don't need a semicolon
					case EBlock(_) | EIf(_) | EWhile(_) | EFun(_, _) | EClass(_, _, _):
					default:
						consume(TSemicolon, "Expect ';' after expression.");
				}
				exprs.push(expr);
			}
			return exprs;
		} catch (e:ParseError) {
			return null;
		}
	}

	private function expression(isInline:Bool):Expr {
		switch (peek().type) {
			case TClass | TFun | TVar | TFor | TIf | TReturn | TWhile | TImport | TExport | TLBrace:
				// If anything that is under `fauxDeclaration` is up next
				return fauxDeclaration(isInline);
			default:
				return assignment();
		}
	}

	function importStatement() {
		var importToken = previous();
		var id = consume(TIdentifier, "Expect name after 'import'");
		consume(TFrom, "Expect 'from' after identifier");
		var filename = consume(TString, "Expect filename after 'from'");
		return new Expr(EImport(id.literal, filename.literal), importToken.position);
	}

	function exportStatement() {
		var exportToken = previous();
		var name = consume(TIdentifier, "Expect identifier after 'export'");
		return new Expr(EExport(name.literal), exportToken.position);
	}

	function assignment():Expr {
		var expr = or();
		if (match(TEquals)) {
			var equals = previous();
			var value = assignment();
			switch (expr.type) {
				case EIdent(ename):
					return new Expr(EAssign(ename, value), equals.position);
				case EField(e, field):
					return new Expr(EFieldSet(e, field, value), equals.position);
				default:
					error(equals, "Invalid assignment target.");
			}
		}
		return expr;
	}

	function or():Expr {
		var expr = and();
		while (match(TOr)) {
			var op = previous();
			var right = and();
			expr = new Expr(EBinop(expr, BOr, right), op.position);
		}
		return expr;
	}

	function and() {
		var expr = equality();
		while (match(TOr)) {
			var op = previous();
			var right = equality();
			expr = new Expr(EBinop(expr, BAnd, right), op.position);
		}
		return expr;
	}

	function equality():Expr {
		var expr = comparison();
		while (match(TEqualsEquals, TBangEquals)) {
			var op = previous();
			var right = comparison();
			expr = new Expr(EBinop(expr, op.type == TEqualsEquals ? BEqual : BNotEqual, right), op.position);
		}
		return expr;
	}

	function comparison():Expr {
		var expr = term();
		while (match(TGreaterThan, TGreaterEquals, TLessThan, TLessEquals)) {
			var op = previous();
			var right = term();
			var goodop = switch (op.type) {
				case TGreaterEquals:
					BGreaterEqual;
				case TGreaterThan:
					BGreater;
				case TLessEquals:
					BLessEqual;
				case TLessThan:
					BLess;
				default:
					null;
			};
			expr = new Expr(EBinop(expr, goodop, right), op.position);
		}
		return expr;
	}

	function term() {
		var expr = factor();
		while (match(TPlus, TMinus)) {
			var op = previous();
			var right = factor();
			expr = new Expr(EBinop(expr, op.type == TPlus ? BAdd : BSub, right), op.position);
		}
		return expr;
	}

	function factor() {
		var expr = unary();
		while (match(TStar, TSlash)) {
			var op = previous();
			var right = unary();
			expr = new Expr(EBinop(expr, op.type == TStar ? BMul : BDiv, right), op.position);
		}
		return expr;
	}

	function unary() {
		if (match(TBang, TMinus)) {
			var op = previous();
			var right = unary();
			return new Expr(EUnop(op.type == TBang ? UNot : UNegate, right), op.position);
		}
		return call();
	}

	function call() {
		var expr = primary();
		while (true) {
			if (match(TLParen, TDot, TLBracket)) {
				switch (previous().type) {
					case TLParen:
						expr = finishCall(expr);
					case TDot:
						var name = consume(TIdentifier, "Expect property name after '.'.");
						expr = new Expr(EField(expr, name.literal), name.position);
					case TLBracket:
						var index = expression(true);
						consume(TRBracket, "Expect ']' after index.");
						expr = new Expr(EArrayAccess(expr, index), index.pos);
					default:
						break;
				}
			} else
				break;
		}
		return expr;
	}

	function finishCall(callee:Expr) {
		var args = [];
		if (!check(TRParen)) {
			do {
				if (args.length >= 256) {
					error(peek(), "Cannot have more than 255 arguments.");
				}
				args.push(expression(true));
			} while (match(TComma));
		}
		var paren = consume(TRParen, "Expect ')' after arguments.");

		return new Expr(ECall(callee, args), paren.position);
	}

	function primary() {
		var next = advance();
		switch (next.type) {
			case TTrue | TFalse:
				return new Expr(EBool(next.type == TTrue), next.position);
			case TNil:
				return new Expr(ENil, next.position);
			case TNumber:
				return new Expr(ENumber(next.literal), next.position);
			case TString:
				return new Expr(EString(next.literal), next.position);
			case TNone:
				return new Expr(ENone, next.position);
			case TIdentifier:
				return new Expr(EIdent(next.literal), next.position);
			case TLParen:
				var expr = expression(true);
				consume(TRParen, "Expect ')' after expression.");
				return new Expr(EGroup(expr), expr.pos);
			case TSuper:
				consume(TDot, "Expect '.' after super");
				var id = consume(TIdentifier, "Expect superclass method name.");
				return new Expr(ESuper(id.literal), id.position);
			case TLBracket:
				return array();
			case TObjOpen:
				return object();
			case TReserved:
				throw error(next, "Unexpected Reserved Keyword" + next.lexeme);
			default:
				throw error(next, "Unexpected Token: " + next);
		}
	}

	function array() {
		var openBracket = previous();
		var elements:Array<Expr> = [];
		if (!check(TRBracket)) {
			do {
				elements.push(expression(true));
			} while (match(TComma));
		}
		consume(TRBracket, "Expect ']' after elements.");

		return new Expr(EArrayDecl(elements), rangePos(openBracket.position, previous().position));
	}

	function rangePos(first:Position, last:Position) {
		return new Position(first.min, last.max, first.file);
	}

	function object() {
		var openBrace = previous();
		var fields:Array<Var> = [];
		do {
			var name = consume(TIdentifier, "Expect property name.");
			consume(TColon, "Expect ':' after property name.");
			var value = expression(true);
			fields.push({name: name.literal, value: value});
		} while (match(TComma));
		consume(TRBrace, "Expect '}' after fields.");
		return new Expr(EObjDecl(fields), rangePos(openBrace.position, previous().position));
	}

	function fauxDeclaration(isInline:Bool):Expr {
		var next = advance();
		switch (next.type) {
			case TClass:
				return classDeclaration();
			case TFun:
				return funDeclaration(isInline);
			case TVar:
				return varDeclaration();
			case TFor:
				return forStatement();
			case TIf:
				return ifStatement(isInline);
			case TReturn:
				return returnStatement();
			case TWhile:
				return whileStatement();
			case TImport:
				return importStatement();
			case TExport:
				return exportStatement();
			case TLBrace:
				return block();
			default:
				throw error(next, "Unexpected token when expecting a statement: " + next.type);
		}
	}

	function consume(type:TokenType, message:String) {
		if (peek().type == TReserved)
			throw error(peek(), "Error: " + message + "; Found reserved word.");
		if (check(type))
			return advance();
		throw error(peek(), message);
	}

	function error(token:Token, message:String) {
		Lox.error(token.position, message);
		return new ParseError();
	}

	function classDeclaration() {
		var name = consume(TIdentifier, "Expect Identifier after 'class'.");
		var superclass = null;
		if (match(TExtends)) {
			superclass = consume(TIdentifier, "Expect superclass name after 'extends'.").literal;
		}
		consume(TLBrace, "Expect '{' after class name.");
		var fields:Array<ClassField> = [];
		var accessmodifiers:Array<AccessModifier> = [];
		while (true) {
			switch (advance().type) {
				case TPrivate:
					accessmodifiers.push(APrivate);
				case TPublic:
					accessmodifiers.push(APublic);
				case TDynamic:
					accessmodifiers.push(ADynamic);

				case TStatic:
					accessmodifiers.push(AStatic);
				case TOverride:
					accessmodifiers.push(AOverride);

				case TFun:
					var fun = funDeclaration(false);
					switch (fun.type) {
						case EFun(name, fun):
							fields.push({access: accessmodifiers.copy(), name: name, value: FVFun(fun)});
							accessmodifiers = [];
						default:
					}
				case TVar:
					var evar = varDeclaration();
					consume(TSemicolon, "Expect ';' after var declaration.");
					switch (evar.type) {
						case EVar(vvalue):
							fields.push({access: accessmodifiers.copy(), name: vvalue.name, value: FVVar(vvalue.value)});
							accessmodifiers = [];
						default:
					}
				case TRBrace:
					break;
				case token:
					throw error(peek(), "Unexpected token: " + token);
			}
		}
		return new Expr(EClass(name.literal, fields, superclass), name.position);
	}

	function funDeclaration(isInline:Bool):Expr {
		var fun = previous();
		var name = null;
		if (isInline)
			name = if (match(TIdentifier)) previous().literal else "<anonymous fn>";
		else
			name = consume(TIdentifier, "Expect function name.").literal;
		var args:Array<String> = [];
		consume(TLParen, "Expect '(' after function name.");
		if (!check(TRParen)) {
			do {
				if (args.length > 256) {
					throw error(peek(), "Cannot have more than 256 arguments.");
				}
				args.push(consume(TIdentifier, "Expect parameter name.").literal);
			} while (match(TComma));
		}
		consume(TRParen, "Expect ')' after parameters.");
		consume(TLBrace, "Expect '{' before function body.");
		var body = block();
		return new Expr(EFun(name, {args: args, body: body}), fun.position);
	}

	function varDeclaration():Expr {
		var name = consume(TIdentifier, "Expect variable name.");
		var initializer = new Expr(ENone, name.position);
		if (match(TEquals)) {
			initializer = expression(true);
		}
		return new Expr(EVar({name: name.literal, value: initializer}), name.position);
	}

	function ifStatement(isInline:Bool = false):Expr {
		consume(TLParen, "Expect '(' after 'if'.");
		var condition = expression(true);
		consume(TRParen, "Expect ')' after if condition.");
		var thenBranch = expression(isInline);
		if (!isInline)
			consumeSemicolonIfApplicable(thenBranch);
		var elseBranch = new Expr(ENone, condition.pos);
		if (match(TElse)) {
			elseBranch = expression(isInline);
			if (!isInline) {
				consumeSemicolonIfApplicable(elseBranch);
			}
		} else if (isInline) {
			error(peek(), "If statements used as expressions must have an else branch.");
		}
		return new Expr(EIf(condition, thenBranch, elseBranch), condition.pos);
	}

	function returnStatement():Expr {
		var keyword = previous();
		var value = new Expr(ENone, keyword.position);
		if (!check(TSemicolon)) {
			value = expression(true);
		}
		return new Expr(EReturn(value), keyword.position);
	}

	function forStatement():Expr {
		var forToken = previous();
		consume(TLParen, "Expect '(' after 'for'.");
		var initializer = null;
		if (!match(TSemicolon))
			initializer = expression(true);
		var condition = new Expr(EBool(true), peek().position);
		if (!check(TSemicolon)) {
			condition = expression(true);
		}
		var increment = new Expr(ENone, peek().position);
		if (!check(TRParen)) {
			increment = expression(true);
		}
		consume(TRParen, "Expect ')' after for clauses.");
		var body = expression(true);
		consumeSemicolonIfApplicable(body);
		var exprs = [];
		if (initializer != null) {
			exprs.push(initializer);
		}
		body = new Expr(EBlock([body, increment]), forToken.position);
		var whileLoop = new Expr(EWhile(condition, body), body.pos);
		exprs.push(whileLoop);
		return new Expr(EBlock(exprs), forToken.position);
	}

	function whileStatement():Expr {
		var whileToken = previous();
		consume(TLParen, "Expect '(' after 'while'.");
		var condition = expression(true);
		consume(TRParen, "Expect ')' after condition.");
		var body = expression(true);
		consumeSemicolonIfApplicable(body);
		return new Expr(EWhile(condition, body), whileToken.position);
	}

	function consumeSemicolonIfApplicable(expr:Expr) {
		switch (expr.type) {
			case EBlock(_):
			default:
				consume(TSemicolon, "Expect ';'.");
		}
	}

	function block():Expr {
		var firstBrace:Token = previous();
		var exprs:Array<Expr> = [];
		while (!check(TRBrace) && !isAtEnd()) {
			var expr = expression(false);
			exprs.push(expr);
			switch (expr.type) {
				// These don't need a semicolon
				case EBlock(_) | EIf(_) | EWhile(_) | EFun(_, _):
				default:
					consume(TSemicolon, "Expect ';' after expression.");
			}
		}
		var secondBrace = consume(TRBrace, "Expect '}' after block.");
		return new Expr(EBlock(exprs), rangePos(firstBrace.position, secondBrace.position));
	}

	private function match(...tokenType:TokenType) {
		for (type in tokenType) {
			if (check(type)) {
				advance();
				return true;
			}
		}
		return false;
	}

	private function check(tokenType:TokenType) {
		if (isAtEnd()) {
			return false;
		}
		return peek().type == tokenType;
	}

	private function advance() {
		if (!isAtEnd()) {
			current++;
		}
		return previous();
	}

	private function isAtEnd() {
		return peek().type == TEof;
	}

	private function peek() {
		return tokens[current];
	}

	function peekNext() {
		return tokens[current + 1];
	}

	private function previous() {
		return tokens[current - 1];
	}
}

class ParseError extends haxe.Exception {
	public function new() {
		super("");
	}
}
