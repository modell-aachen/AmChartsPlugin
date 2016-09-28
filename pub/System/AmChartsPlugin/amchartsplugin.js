(function($) {
$(function(){
	AmCharts.useUTC = true;
	AmCharts.shortMonthNames = [
	  'Jan',
	  'Feb',
	  'Mrz',
	  'Apr',
	  'Mai',
	  'Jun',
	  'Jul',
	  'Aug',
	  'Sep',
	  'Okt',
	  'Nov',
	  'Dez'];

	AmCharts.balloonDateFormat =[
	{period:'fff',format:'JJ:NN:SS'},
	{period:'ss',format:'JJ:NN:SS'},
	{period:'mm',format:'JJ:NN'},
	{period:'hh',format:'JJ:NN'},
	{period:'DD',format:'MMM DD'},
	{period:'WW',format:'MMM DD'},
	{period:'MM',format:'MMM'},
	{period:'YYYY',format:'YYYY'}];

	var generalAmChartsOptions = {
	  "type": "gantt",
	  "period": "WW",
	  "dataDateFormat": "YYYY-MM-DD",
	  "balloonDateFormat": "JJ:NN",
	  "columnWidth": 0.5,
	  "plotAreaBorderAlpha": 1,
	  "borderAlpha": 1,
	  "fontFamily": "Akkurat",
	  "fontSize": 14,
	  "valueAxis": {
	    "type": "date",
	    "minimum": 1,
	    "guides": [{
	      "value":new Date().getTime(),
	      "toValue":new Date().getTime(),
	      "lineAlpha": 1,
	      "lineColor": "#d7191c",
	      "lineThickness": 3
	    }]
	  },

	   "zoomOutButtonAlpha": 0.21,
	   "zoomOutButtonColor": "#143E6F",
	   "zoomOutButtonRollOverAlpha": 0.66,
	   "zoomOutText": "Alles anzeigen",

	  "brightnessStep": 10,
	  "graph": {
	    "fillAlphas": 1,
	    "balloonText": "<b><h2>[[category]]</h2></b><b>[[text]]",
	    "bulletField": "bullet",
	    "bulletSize": 20,
	    "bulletBorderAlpha": 1,
	    "bulletBorderColor": "#000000",
	    "bulletBorderThickness": 1
	  },
	  "rotate": true,
	  "categoryField": "category",
	  "segmentsField": "segments",
	  "colorField": "color",
	  "startDateField": "start",
	  "endDateField": "end",
	  "durationField": "duration",

	  "valueScrollbar": {
	    "autoGridCount": true
	  },
	  "chartCursor": {
	    "valueBalloonsEnabled": false,
	    "cursorAlpha": 0,
	    "valueLineAlpha": 0.5,
	    "valueLineBalloonEnabled": true,
	    "valueLineEnabled": true,
	    "zoomable": true,
	    "valueZoomable": true,
	    "categoryBalloonDateFormat": "JJ:NN",
	    "cursorColor": "#143E6F",
	    "graphBulletSize": 1

	  },
	  "export":{
	    "enabled": true
	  }
	};

  	var changeChart = function(projectId, type){
  		$(".gantt-loading").show();
  		$.getJSON("/bin/rest/AmChartsPlugin/gantt", {projectId: projectId, type: type}, function(data){
        ganttChart.startDate = new Date(data[0]["segments"][0]["start"]);
        ganttChart.startDate.setMonth(ganttChart.startDate.getMonth() - 1);
  			ganttChart.dataProvider = data;
  			ganttChart.validateData();
  			var downloadData = "text/json;charset=utf-8," + encodeURIComponent(JSON.stringify(data));
  			$("#ganttJson").attr("href", "data:" + downloadData);
  			$("#ganttJson").attr("download", type + ".json");
  			$(".gantt-loading").hide();
		  });
  	}

  	$("#ganttSelect").change(function(event){
  		ganttType = $(this).val();
  		changeChart(projectId, ganttType);
  	});

  	$("#ganttRefresh").click(function(){
  		changeChart(projectId, ganttType);
  		event.preventDefault();
  	});

    var projectId = foswiki.preferences.WEB + "." + foswiki.preferences.TOPIC;
  	var ganttChart = AmCharts.makeChart("ganttChart", generalAmChartsOptions);
  	var ganttType = "coarse";
  	changeChart(projectId, ganttType);


  	$('.tasktracker:visible').livequery( function() {
  		$(this).on("editorLoad", function(evt, opts){
	  		$(opts.editor).find("[name='Type']").change(function(evt){
	  			var $startDateField = $(opts.editor).find(".start-date");
	  			var showStartDate = (evt.target.value === "Taskpackage");
	  			showStartDate ? $startDateField.css("display", "") : $startDateField.css("display", "none");
	  		});
	  	});
        $(this).on("afterSave", function(){
            changeChart(projectId, ganttType);
        });
  	});
});
})(jQuery);
