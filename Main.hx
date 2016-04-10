package;

import asys.FileSystem;
import asys.io.File;

using tink.CoreApi;

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
					return @:await FileSystem.rename(path, path+'1');					
				default: 
					return '';
			}
		} else {
			throw 'error';
		}
	}
	
	public static function main() {
		new Main();
	}
	
}