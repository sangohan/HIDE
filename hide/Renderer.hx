package hide;

// ----- Default Rendering --------------------------------

class DefaultForwardComposite extends h3d.shader.ScreenShader {
	static var SRC = {
		@param var texture : Sampler2D;
		@param var outline : Sampler2D;

		function fragment() {
			pixelColor = texture.get(calculatedUV);
			var outval = outline.get(calculatedUV).rgb;
			if(outval.r > 0.1 && outval.r < 0.5)
				pixelColor.rgb += outval.rgb * 3.0 + 0.1;
		}
	}
}

class MaterialSetup extends h3d.mat.MaterialSetup {
    override public function createRenderer() {
	    return new Renderer();
	}

	override function getDefaults( ?type : String ) : Any {
		if(type == "ui") return {
			kind : "Alpha",
			shadows : false,
			culled : false,
			lighted : false
		};
		return super.getDefaults(type);
	}
}

class Renderer extends h3d.scene.DefaultRenderer {

	var composite: h3d.pass.ScreenFx<DefaultForwardComposite>;
	var outline = new ScreenOutline();
	var outlineBlur = new h3d.pass.Blur(4);

	public function new() {
		super();
		composite = new h3d.pass.ScreenFx(new DefaultForwardComposite());
	}

	override function render() {

		var output = allocTarget("output");
		setTarget(output);
		clear(h3d.Engine.getCurrent().backgroundColor, 1, 0);

		if( has("shadow") )
			renderPass(shadow,get("shadow"));

		if( has("depth") )
			renderPass(depth,get("depth"));

		if( has("normal") )
			renderPass(normal,get("normal"));

		renderPass(defaultPass, getSort("default", true) );
		renderPass(defaultPass, getSort("alpha") );
		renderPass(defaultPass, get("additive") );
		renderPass(defaultPass, getSort("debuggeom") );
		renderPass(defaultPass, getSort("debuggeom_alpha"));
		renderPass(defaultPass, getSort("overlay") );
		renderPass(defaultPass, getSort("ui"));


		var outlineTex = allocTarget("outlineBlur", false);
		{
			var outlineSrcTex = allocTarget("outline", false);
			setTarget(outlineSrcTex);
			clear(0);
			draw("highlight");
			resetTarget();
			outlineBlur.apply(ctx, outlineSrcTex, outlineTex);
		}

		resetTarget();
		composite.shader.texture = output;
		composite.shader.outline = outlineTex;
		composite.render();
	}
}

// ----- PBR Rendering --------------------------------

class PbrSetup extends h3d.mat.PbrMaterialSetup {

	function getEnvMap() {
		var ide = hide.Ide.inst;
		var scene = hide.comp.Scene.getCurrent();
		var path = ide.getPath(scene.config.get("scene.environment"));
		var data = sys.io.File.getBytes(path);
		var pix = hxd.res.Any.fromBytes(path, data).toImage().getPixels();
		var t = h3d.mat.Texture.fromPixels(pix); // sync
		t.name = ide.makeRelative(path);
		return t;
	}

    override function createRenderer() {
		var env = new h3d.scene.pbr.Environment(getEnvMap());
		env.compute();
		return new PbrRenderer(env);
	}

	override function getDefaults( ?type : String ) : Any {
		if(type == "ui") return {
			mode : "Overlay",
			blend : "Alpha",
			shadows : false,
			culled : false,
			lighted : false
		};
		return super.getDefaults(type);
	}
}

class ScreenOutline extends h3d.shader.ScreenShader {
	static var SRC = {

		@param var texture: Sampler2D;

		function vertex() {
		}

		function fragment() {
			var uv = input.uv;
			var outval = texture.get(uv).rgb;
			if(outval.r > 0.1 && outval.r < 0.5)
				pixelColor.rgb += outval.rgb*3.0 + 0.1;
		}
	};
}

class PbrRenderer extends h3d.scene.pbr.Renderer {

	var outline = new ScreenOutline();
	var outlineBlur = new h3d.pass.Blur(4);

	public function new(env) {
		super(env);
		tonemap.addShader(outline);
	}

	override function getDefaultProps( ?kind : String ) : Any {
		var props : h3d.scene.pbr.Renderer.RenderProps = super.getDefaultProps(kind);
		props.sky = Background;
		return props;
	}

	override function mainDraw() {
		output.draw(getSort("default", true));
		output.draw(getSort("alpha"));
		output.draw(get("additive"));


		var outlineTex = allocTarget("outline", false);
		setTarget(outlineTex);
		clear(0);
		draw("highlight");

		var outlineBlurTex = allocTarget("outlineBlur", false);
		outlineBlur.apply(ctx, outlineTex, outlineBlurTex);
		outline.texture = outlineBlurTex;
	}

	override function postDraw() {
		defaultPass.draw(getSort("debuggeom"));
		defaultPass.draw(getSort("debuggeom_alpha"));
		defaultPass.draw(getSort("overlay"));
		defaultPass.draw(getSort("ui"));
	}
}

