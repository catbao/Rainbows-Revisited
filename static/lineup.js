// const fs = require('fs');
function Lineup(w, h, n, realModel, decoyModel, nullOption, trialOrder, blockOrder)
{
    // total number of exposures (n-1 actual + 1 decoy)
    this.w = w;
    this.h = h;
    this.n = n;

    this.realModel = realModel;
    this.decoyModel = decoyModel;

    // create canvases and samplers
    this.canvases = [];
    this.samplers = [];
    this.nullOption = nullOption;

    for (let i=0; i<4; i++)
    {
        console.log("first");
        let canvas = document.createElement('canvas');
        canvas.width = w;
        canvas.height = h;
        canvas.id="sample" + i;
        console.log("trailOrder:", trialOrder)
        let image = new Image();
        if(i === 0)
            image.src = `./static/img/Viridis/Viridis_${trialOrder}_output1.png`;
        if(i === 1)
            image.src = `./static/img/Viridis/Viridis_${trialOrder}_output2.png`;
        if(i === 2)
            image.src = `./static/img/Viridis/Viridis_${trialOrder}_output3.png`;
        if(i === 3)
            image.src = `./static/img/Viridis/Viridis_${trialOrder}_target_output.png`;

        (function(index, img) {
            img.onload = function() {
                let context = canvas.getContext('2d');
                context.drawImage(img, 0, 0, canvas.width, canvas.height);
            };
        })(i, image);
        this.canvases.push( canvas );
        // console.log(this.canvases)
        // sampler
        // let sampler = new ScalarSample(w, h, canvas, i==n-1 ? this.decoyModel : this.realModel);
        // this.samplers.push(sampler);
    }

}

function download(filename, text) {
    let element = document.createElement('a');
    element.setAttribute('href', 'data:text/plain;charset=utf-8,' + encodeURIComponent(text));
    element.setAttribute('download', filename);

    element.style.display = 'none';
    document.body.appendChild(element);

    element.click();

    document.body.removeChild(element);
}

Lineup.prototype.sample = function(samplingRate, noDecoy) 
{
    if (noDecoy) {
        console.log('sampling no decoy (fidelity: ' + samplingRate + ')');
    }
    let index = 1;
   
    for (let i=0; i<this.samplers.length; i++)
    {
        // console.log("trailOrder:", trialOrder)
        // let image = new Image();
        // if(i === 0)
        //     image.src = `./static/img/Viridis/Viridis_${trialOrder}_output1.png`;
        // if(i === 1)
        //     image.src = `./static/img/Viridis/Viridis_${trialOrder}_output2.png`;
        // if(i === 2)
        //     image.src = `./static/img/Viridis/Viridis_${trialOrder}_output3.png`;
        // if(i === 3)
        //     image.src = `./static/img/Viridis/Viridis_${trialOrder}_target_output.png`;

        // (function(index, img) {
        //     img.onload = function() {
        //         let context = canvas.getContext('2d');
        //         context.drawImage(img, 0, 0, canvas.width, canvas.height);
        //     };
        // })(i, image);
        // this.canvases.push( canvas );

        this.samplers[i].sampleModel(samplingRate, noDecoy ? this.realModel : undefined);
        // console.log("abc:", this.samplers[i].visualizer.field.view);
        // console.log("abc:", this.samplers[i]);

        let array = Array.from(this.samplers[i].visualizer.field.view);
        console.log(Array.isArray(array)); 
        let twoDimView = [];
        for (let i = 0; i < 200; i++) {
            twoDimView[i] = array.slice(i * 200, (i + 1) * 200);
        }
        let arrayAsText = twoDimView.map(row => row.join(',')).join('\n');
        if(i===3)
            download(`${index}_target_output.csv`, 'Row,Column\n' + arrayAsText);
        else
            download(`${index}_output${i+1}.csv`, 'Row,Column\n' + arrayAsText);

        // this.samplers[i].vis();
    }
}

let LINEUP_PADDING = 6;

Lineup.prototype.layoutCanvases = function(table)
{
    if (!table) {
        table = this.table;
    }
    // console.log("table:", table, this.canvases);
    let trial = this.trialOrder;
    let block = this.blockOrder;
    let color_data = null;
    if(block === 1){
        color_data = 'Viridis';
        document.getElementById('colorbar_pic').src = "/static/img/ColorMap/Viridis_colormap.png";
    }
    else if(block === 2){
        color_data = 'Rainbow'; 
        document.getElementById('colorbar_pic').src = "/static/img/ColorMap/Rainbow_colormap.png";
    }
    else if(block === 3){
        color_data = 'Ours';
        if(trial === 10) document.getElementById('colorbar_pic').src = "/static/img/ColorMap/Ours_colormap_2.png";
        else if(trial === 8) document.getElementById('colorbar_pic').src = "/static/img/ColorMap/Ours_colormap_5.png";
        else if(trial === 11 || trial === 14) document.getElementById('colorbar_pic').src = "/static/img/ColorMap/Ours_colormap_4.png";
        else document.getElementById('colorbar_pic').src = "/static/img/ColorMap/Ours_colormap_3.png";
        // document.getElementById('colorbar_pic').src = "/static/img/ColorMap/Ours_colormap.png";
    }
    else if(block === 4){
        color_data = 'OMC';
        document.getElementById('colorbar_pic').src = "/static/img/ColorMap/OMC_colormap.png";
    }
    else if(block === 5){
        color_data = 'Viridis_hist_eq';
        document.getElementById('colorbar_pic').src = "/static/img/ColorMap/Viridis_colormap.png";
    }
    else if(block === 6){
        color_data = 'Rainbow_hist_eq';
        document.getElementById('colorbar_pic').src = "/static/img/ColorMap/Rainbow_colormap.png";
    }
    console.log("trial:", trial);
    // console.log(this.canvases);
    for(let i=0; i<4; i++){
        let image = new Image();
        let canvas = this.canvases[i];
        // console.log("currentCanvas:", canvas);
        if(i === 0){
            image.src = `./static/img/${color_data}/${color_data}_${trial}_output1.png`;
            // console.log(image.src);
            let context = canvas.getContext('2d');
            context.clearRect(0, 0, canvas.width, canvas.height); 
            image.onload = function() {  
                console.log(image.src);  
                context.drawImage(image, 0, 0, canvas.width, canvas.height);  
            };  
        }
        if(i === 1){
            image.src = `./static/img/${color_data}/${color_data}_${trial}_output2.png`;
            console.log(image.src);
        }
        if(i === 2)
            image.src = `./static/img/${color_data}/${color_data}_${trial}_output3.png`;
        if(i === 3)
            image.src = `./static/img/${color_data}/${color_data}_${trial}_target_output.png`;

        // console.log("canvas:", canvas);
        (function(index, img) {
            img.onload = function() {
                let context = canvas.getContext('2d');
                context.drawImage(img, 0, 0, 200, 200);
            };
        })(i, image);
    }
    // this.canvases.push( canvas );

    let randomCanvases = this.canvases.slice();
    let decoyCanvas = randomCanvases.pop();

    // reinsert
    let insertPos = Math.floor( Math.random() * (randomCanvases.length+1) );
    randomCanvases.splice(insertPos, 0, decoyCanvas);


    // remove everything in the table
    table.selectAll('*').remove();
    table.attr('cellpadding', LINEUP_PADDING).attr("cellspacing", "0")
    // how many rows
    let rows = 2;
    let cols = Math.ceil(this.n/2);

    (function(table, rows, cols, n, randomCanvases, nullOption)
    {
        let rs = d3.range(rows);
        table.selectAll('tr').data(rs)
            .enter().append('tr')
            .each(function(d, thisRow) 
            {
                (function(rowNum, thisRow) 
                {
                    d3.select(thisRow).selectAll('td').data(d3.range(cols))
                        .enter().append('td').each(function(d, i) {
                            let index = i + rowNum*cols;
                            if (index < n) 
                            {
                                this.appendChild( randomCanvases[index] );
                                d3.select(randomCanvases[index])
                                    .attr('class', 'index' + index);
                            }
                        });

                    if (rowNum==0 && nullOption) 
                    {
                        let w_div = +d3.select(randomCanvases[0]).attr('width')
                        let w = 25 + w_div;
                        let h = +d3.select(randomCanvases[0]).attr('height');
                        let tdNull = d3.select(thisRow).append('td')
                            .attr('rowSpan', rows)
                            .attr('width', w);

                        let div = tdNull.append('div')
                            .style('margin', '0 auto')
                            .style('width', w + 'px');
                        div.append('div')
                            .style('margin-top', ((rows*h)/2-h/1) + 'px')
                            .style('margin-left', 'auto')
                            .style('margin-right', 'auto')
                            .attr('class', 'nullOption')
                            .style('text-align', 'center')
                            .style('vertical-align', 'middle')
                            .style('width', w_div + 'px')
                            .style('height', h + 'px')
                            .style('border', 'solid 1px black')
                            .style('font-size', '35px')
                            .style('color', "#bbbbbb")
                            .style('font-weight', 'bold')
                            .html('no discernible difference between images');
                    }
                })(d, this);
            });
    })(table, rows, cols, this.n, randomCanvases, this.nullOption);
    this.table;

}
