package
{
	import flash.display.Bitmap;
	import starling.display.MovieClip;
	import starling.core.Starling;
	import starling.textures.Texture;
	import starling.display.Sprite;
	import starling.textures.TextureAtlas;
	
	/**
	 * ...
	 * @author Aspirin
	 */
	public class TextureAtlasTest extends Sprite
	{
		
		public function TextureAtlasTest()
		{
		
		}
		
		public function setAtlas(bm:Bitmap, xml:XML):void
		{
			var texture:Texture = Texture.fromBitmap(bm);
			var atlas:XML = xml;
			
			var ta:TextureAtlas = new TextureAtlas(texture, atlas);
			var img : starling.display.Image
			var mc:MovieClip = new MovieClip(ta.getTextures("hand_0"), 15);
			mc.x = 600;
			addChild(mc);
			Starling.juggler.add(mc);
		}
	
	}

}