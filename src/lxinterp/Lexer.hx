package lxinterp;

import lxinterp.Token.TokenType;
import lxinterp.Position;

class Lexer {
    static final keywords = [
        "extends" => TExtends,
        "class" => TClass,
        "fun" => TFun,
        "var" => TVar,
        "for" => TFor,
        "if" => TIf,
        "else" => TElse,
        "return" => TReturn,
        "while" => TWhile,
        "and" => TAnd,
        "or" => TOr,
        "true" => TTrue,
        "false" => TFalse,
        "nil" => TNil,
        "super" => TSuper, 
        "private" => TPrivate,
        "dynamic" => TDynamic,
        "static" => TStatic,
        "override" => TOverride,
        "public" => TPublic,
        "import" => TImport,
        "export" => TExport,
        "from" => TFrom,
        "in" => TReserved,
        "as" => TReserved,
        "is" => TReserved,
        "not" => TReserved,
        "new" => TReserved,
        "match" => TReserved,
        "case" => TReserved,
        "enum" => TReserved,
        "interface" => TReserved,
        // Contract will be an interface that can't have partial implementations
        "contract" => TReserved,
        "implements" => TReserved,
        "signs" => TReserved,
        "abstract" => TReserved,
        "None" => TNone
    ];
    final src:String;
    final fileName:String;
    var curPos:Point = new Point(0, 0, 0); 
    var lastPos:Point = new Point(0, 0,0 );
    var tokens:Array<Token> = [];

    public function new(source:String, ?fileName:String = "<unknown>") {
        this.src = source;
        this.fileName = fileName;
    }
    public function tokenize() {
        while (!isAtEnd()) {
            var c = consume();
            switch (c) {
                case "#" if (match("{")): addToken(TObjOpen); 
                case ":": addToken(TColon);
                case "{": addToken(TLBrace);
                case "}": addToken(TRBrace);
                case "(": addToken(TLParen);
                case ")": addToken(TRParen);
                case "[": addToken(TLBracket);
                case "]": addToken(TRBracket);
                case ",": addToken(TComma);
                case ".": addToken(TDot);
                case ";": addToken(TSemicolon);
                case "*": addToken(TStar);
                case "+": addToken(TPlus);
                case "-": addToken(TMinus);
                case "!": if (match("=")) addToken(TBangEquals) else addToken(TBang);
                case "=": if (match("=")) addToken(TEqualsEquals) else addToken(TEquals);
                case "<": if (match("=")) addToken(TLessEquals) else addToken(TLessThan);
                case ">": if (match("=")) addToken(TGreaterEquals) else addToken(TGreaterThan);
                case "/": if (match("/")) {
                    while (!isAtEnd() && peek() != '\n') {
                        consume();
                    }
                    
                } else {
                    addToken(TSlash);
                }
                case ' ' | '\t' :
                // Don't count as a character
                case '\r': 
                    if (curPos.column != 0)
                        curPos.column--; 
                case '\n': 
                    curPos.column = 0;
                    curPos.line++;
                case '"': string(false);
                case '@': if (match('"')) string(true); else Lox.error(correctPosition(), "@ may only precede verbatim strings.");
                default: 
                    if (isDigit(c)) number();
                    else if (isAlpha(c)) {
                        var id = identifier();
                        if (keywords.exists(id)) {
                            addToken(keywords[id]);
                        } else {
                            addToken(TIdentifier, id);
                        }
					} else
						Lox.error(correctPosition(), "Unexpected Character.");
            }
            lastPos = curPos.copy();
        }
        addToken(TEof);
        return tokens;
    }
    private function correctPosition() {
        
        var goodPos = curPos.copy();
		goodPos.column--;
		goodPos.absPos--;
        

        return new Position(lastPos, goodPos, fileName);
    }
    private function string(verbatim:Bool) {
        var goodString = "";
        while (!isAtEnd()) {
            if (!verbatim) {
				switch (peek()) {
					case '\n':
						curPos.line++;
						curPos.column = 0;
						curPos.absPos++;
					case '\\' if (peekNext() == '"'):
						consume();
						consume();
						goodString += '"';
					case '\\' if (peekNext() == '\\'):
						consume();
						consume();
						goodString += '\\';
					case '\\' if (peekNext() == 'n'):
						consume();
						consume();
						goodString += '\n';
					case '\\':
						Lox.error(new Position(curPos, curPos, fileName), "Unrecognized escape sequence");
					case '\r':
						// Don't count as a character for cross platformness
						consume();
						curPos.column--;
					case '"':
						consume();
						break;
					default:
						goodString += consume();
				}
            } else {
                // Verbatim interprets strings "Verbatim", meaning escaping is ignored.
                // Only thing that can be escaped is a quote, which is done by doing it twice in a row.
                // We stan C# :heart:
                switch (peek()) {
                    case '\n':
                        curPos.line++;
                        curPos.column = 0;
                        curPos.absPos++;
                    case '"' if (peekNext() == '"'):
                        consume();
                        consume();
                        goodString += '"';
                    case '\r': 
                        // Don't count as a character for cross platformness
                        consume();
                        curPos.column--;
                    case '"': 
                        consume();
                        break;
                    default:
                        goodString += consume();
                }
            }
            
			
        }
		if (isAtEnd()) {
			Lox.error(correctPosition(), "Unterminated string.");
            return;
        }
			
        addToken(TString, goodString);
    }
    function number() {
        while (isDigit(peek())) {
            consume();
        }
        if (peek() == '.' && isDigit(peekNext())) {
            consume();
            while (isDigit(peek())) {
                consume();
            }
        }
        addToken(TNumber, Std.parseFloat(src.substring(lastPos.absPos, curPos.absPos)));
    }
    private function identifier() {
        while (isAlpha(peek()) || isDigit(peek())) {
            consume();
        }
        return src.substring(lastPos.absPos, curPos.absPos);
    }
    private function match(char:String) {
        if (isAtEnd()) return false;
        if (src.charAt(curPos.absPos) != char) return false;
        curPos.absPos++;
        curPos.column++;
        return true;
    }
    @:pure
    private function peek() {
        return isAtEnd() ? null : src.charAt(curPos.absPos);
    }
    @:pure
    private function peekNext() {
        return isAtEnd() ? null : src.charAt(curPos.absPos + 1);
    }
    private function isAtEnd() {
        return curPos.absPos >= src.length;
    }
    private function addToken(type:TokenType, ?literal:Dynamic) {
		var token = new Token(type, literal, src.substring(lastPos.absPos, curPos.absPos), correctPosition());
        this.tokens.push(token);
    }
    public function consume() {
        curPos.column++;
        return src.charAt(curPos.absPos++);
    }
    public function isDigit(c:String) {
        return c >= '0' && c <= '9';
    }
    public function isAlpha(c:String) {
        return (c >= 'a' && c <= 'z') ||
            (c >= 'A' && c <= 'Z') ||
            c == '_';
    }
}