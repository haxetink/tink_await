package;

import asys.FileSystem;
import asys.io.File;

@:build(await.Await.build())
class Main {

	public function new() {
		test();
	}
	
	@:async 
	function test() {
		var path = 'build.hxml';
		if (@:await FileSystem.exists(path)) {
			var content = @:await File.getContent(path);
			trace(content);
		} else {
			trace('File does not exist');
		}
	}
	
	public static function main() {
		new Main();
	}
	
}