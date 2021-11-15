package lxinterp;

class Namespace {
    public final name:String;
    public final children:Map<String, Namespace>;
    public function new(name:String, children:Map<String, Namespace>) {
        this.children = children;
        this.name = name;
    }
}

enum NamespaceValue {
    Class(klass:LoxClass);
    Namespace(namespace:Namespace);
}