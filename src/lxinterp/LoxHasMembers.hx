package lxinterp;

interface LoxHasMembers {
    function get(key:String):Dynamic;
    function set(key:String, value:Dynamic):Void;
}