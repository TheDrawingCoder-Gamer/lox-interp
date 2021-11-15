package lxinterp;

class Token {
	public final literal:Dynamic;
	public final type:TokenType;
	public final position:Position;
	public final lexeme:String;

	public function new(type:TokenType, literal:Dynamic, lexeme:String, position:Position) {
		this.type = type;
		this.literal = literal;
		this.position = position;
		this.lexeme = lexeme;
	}

	public function toString() {
		return '$type($literal)($lexeme) $position ';
	}
}

enum TokenType {
	TExtends;
	TClass;
	TLBrace;
	TRBrace;
	TLBracket;
	TRBracket;
	TObjOpen;
	TColon;
	TFun;
	TVar;
	TEquals;
	TSemicolon;
	TFor;
	TLParen;
	TRParen;
	TIf;
	TElse;
	TReturn;
	TWhile;
	TDot;
	TAnd;
	TOr;
	TEqualsEquals;
	TBangEquals;
	TGreaterEquals;
	TGreaterThan;
	TLessEquals;
	TLessThan;
	TPlus;
	TMinus;
	TStar;
	TSlash;
	TBang;
	TTrue;
	TFalse;
	TNil;
	TSuper;
	TComma;
	TNone;
	TPrivate;
	TPublic;
	TDynamic;
	TStatic;
	TOverride;
	TImport;
	TExport;
	TFrom;
    TPackage;
	// For any keyword we would like to use in the future
	// But currently has no use
	TReserved;
	TNumber;
	TString;
	TIdentifier;
	TEof;
}
