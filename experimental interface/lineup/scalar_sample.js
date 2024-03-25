var BLUR=true;
ALL_SAMPLERS = [];

var vis_shader="varying vec2 oTexCoord;uniform sampler2D scalarField;uniform sampler2D colormap;uniform float contour;void main(){vec4 data = texture2D(scalarField, oTexCoord);vec2 colormapCoord = vec2(data.x, 0.5);if (contour >= 0.0 && abs(data.x-contour) < .0035){gl_FragColor = vec4(0.0, 1.0, 0.0, 1.0);}else{if (data.x >= 0.0){gl_FragColor = texture2D(colormap, colormapCoord);}else{gl_FragColor = mix(texture2D(colormap, colormapCoord), vec4(1.0), 0.7);}}}";
var vertex_shader = "varying vec2 oTexCoord;void main(){oTexCoord = uv;gl_Position = projectionMatrix * modelViewMatrix * vec4( position, 1.0 );}";

var blur_shader = "varying vec2 oTexCoord;uniform sampler2D scalarField;uniform sampler2D colormap;uniform vec2 pitch;const float GAUSS_WEIGHT=1.0/16.0;const vec3 BLUR_KERNEL1 = vec3(1.0, 2.0, 1.0);const vec3 BLUR_KERNEL2 = vec3(2.0, 4.0, 2.0);void main(){vec3 data1 = vec3(texture2D(scalarField, oTexCoord + vec2(-1.0, -1.0) * pitch).x,texture2D(scalarField, oTexCoord + vec2(-1.0, 0.0) * pitch).x,texture2D(scalarField, oTexCoord + vec2(-1.0, +1.0) * pitch).x);vec3 data2 = vec3(texture2D(scalarField, oTexCoord + vec2( 0.0, -1.0) * pitch).x,texture2D(scalarField, oTexCoord ).x,texture2D(scalarField, oTexCoord + vec2( 0.0, +1.0) * pitch).x);vec3 data3 = vec3(texture2D(scalarField, oTexCoord + vec2( 1.0, -1.0) * pitch).x,texture2D(scalarField, oTexCoord + vec2( 1.0, 0.0) * pitch).x,texture2D(scalarField, oTexCoord + vec2( 1.0, +1.0) * pitch).x);float val = GAUSS_WEIGHT * (dot(data1, BLUR_KERNEL1) +dot(data2, BLUR_KERNEL2) +dot(data3, BLUR_KERNEL1));vec2 colormapCoord = vec2(val, 0.5);if (val >= 0.0){gl_FragColor = texture2D(colormap, colormapCoord);}else{gl_FragColor = vec4(1.0);}}";

var _shaderList = [
    {name: 'vis',		shaderCode: vis_shader},
    {name: 'vertex',	shaderCode: vertex_shader},
    {name: 'blur',		shaderCode: blur_shader}
];

function ScalarSample(w, h, canvas, model, colormap)
{
    this.w = w;
    this.h = h;
    this.field = new ScalarField(w, h);
    this.model = model;
    this.canvas = canvas;

    // add myself to the model
    if (model) {
        this.setModel(model);
    }


    if (this.canvas)
    {
        (function(me) {
            me.visualizer = new ColorAnalysis(
                me.field, me.canvas,
                function() { setTimeout(function() {
                    me.initVisPipeline()
                },10); }, _shaderList
            );
        })(this);
    }

    if (!colormap) {
        this.field.setColorMap(getColorPreset('viridis'));
    }
    ALL_SAMPLERS.push(this);
}

ScalarSample.setUniversalColormap = function(colormap) {
    for (var i=0; i<ALL_SAMPLERS.length; i++)
    {
        ALL_SAMPLERS[i].field.setColorMap(colormap);

        // render?
        ALL_SAMPLERS[i].vis();
    }
}

ScalarSample.prototype.setModel = function(_model)
{
    if (this.model) {
        this.model.unregisterCallback(this.callbackID);
        this.model = null;
    }

    this.model = _model;
    (function(me) {
        me.callbackID = me.model.addCallback(function() {
            me.sampleModel();
            if (me.canvas) {
                me.vis();
            }
        });
    })(this);

    if (this.canvas)
    {
        this.sampleModel();
        this.vis();
    }
}

ScalarSample.prototype.setSamplingFidelity = function(fidelity)
{
    this.localN = fidelity;
}

ScalarSample.prototype.sampleModel = function(_fidelity, model)
{
    var fidelity = !isNaN(_fidelity) ? _fidelity : this.localN;
    if (!fidelity || isNaN(fidelity)) {
        fidelity = N;
    }
    if (!model) {
        model = this.model;
    }
    model.sampleModel(fidelity, this.field);
}

ScalarSample.prototype.sampleAndVis = function()
{
    this.sampleModel();
    this.vis();
}

ScalarSample.prototype.vis = function()
{
    if (!this.canvas)
    {
        console.log("Error: ScalarSample doesn't have a canvas.");
    }
    else if (!this.visualizer || !this.visualizer.ready())
    {
        // pipeline not yet ready. Set flag to callVis when it's ready
        this.callVisFlag = true;
    }
    else {
        this.visualizer.run(BLUR ? 'blur' : 'vis');
    }

}

ScalarSample.prototype.initVisPipeline = function()
{
    if (!this.canvas) {
        console.log("Error: ScalarSample doesn't have a canvas.");
        return;
    }

    // standard vis
    var vis = new GLPipeline(this.visualizer.glCanvas);
    vis.addStage({
        uniforms: {
            scalarField: {},
            colormap: {},
            contour: {value: -1.0},
        },
        inTexture: 'scalarField',
        fragment: this.visualizer.shaders['vis'],
        vertex: this.visualizer.shaders['vertex']
    });

    // blur + vis
    var blur = new GLPipeline(this.visualizer.glCanvas);
    blur.addStage({
        uniforms: {
            scalarField: {},
            colormap: {},
            pitch: {value: [1/this.field.w, 1/this.field.h]}
        },
        inTexture: 'scalarField',
        fragment: this.visualizer.shaders['blur'],
        vertex: this.visualizer.shaders['vertex']
    });


    this.visualizer.pipelines = {
        vis: vis,
        blur: blur
    };

    //this.visualizer.createVisPipeline();
    if (this.callVisFlag) {
        this.callVisFlag = false;
        this.vis();
    }
}
