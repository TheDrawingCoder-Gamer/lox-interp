package lxinterp;
@:structInit
class Position {
    public final min:Point;
    public final max:Point;
    public var file:String;
    public function new(min:Point, max:Point, file:String) {
        this.min = min.copy();
        this.max = max.copy();
        this.file = file;
    }
    public function toString() {
        if (min.line != max.line)
            return 'Lines ${min.line + 1}-${max.line + 1}, position ${min.absPos + 1}-${max.absPos + 1}';
        else 
            return 'Line ${min.line + 1}, characters ${min.column + 1}-${max.column + 1}';
    }
    public function copy() {
        return new Position(min.copy(), max.copy(), file);
    }
}
@:structInit
class Point {
    public var line:Int;
    public var column:Int;
    public var absPos:Int;
    public function new(line:Int, column:Int, absPos:Int) {
        this.line = line;
        this.column = column;
        this.absPos = absPos;
    }
    public function copy() {
        return new Point(line, column, absPos);
    }
}