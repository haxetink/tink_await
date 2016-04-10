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
		if (@:await FileSystem.exists(@:await FileSystem.fullPath('build.hxml'))) {
			switch @:await File.getContent(path) {
				case 'ok': 
					var yes = @:await FileSystem.rename(path, path+'1');
					trace(yes);
				default: trace('error');
			}
		} else {
			trace('File does not exist');
		}
	}
	
	public static function main() {
		new Main();
	}
	
}