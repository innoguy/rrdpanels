#!/bin/bash

RRA="0"
MIN_WIDTH=1000
HEIGHT=800
LINE_WIDTH=1
DB="/var/log/panels"

OPTS="hv:d:o:t:s:e:r:h:w"
LONGOPTS="help,verbose:,database:,output:,start:,end:,rra:,height:,min-width:"
print_help() {
	cat <<EOF
Usage: $(basename $0) [OTHER OPTIONS]

  -h, --help            this help message
  -v, --verbose         show raw data on stdout
  -d, --database        base filename for the .rrd file
  -o, --output          base filename for the .png file
  -t, --type            all, net or system in graph
  -s, --start           start time of graph (defaults to start of archive)
  -e, --end             end time of graph (defaults to end of archive)
  -r, --rra             rra index to use for first and last element   
      --height          graph height (in pixels, default: 800)
      --min-width       minimum graph width (default: 1000)
EOF
}

! PARSED=$(getopt --options=${OPTS} --longoptions=${LONGOPTS} --name "$0" -- "$@")
if [ ${PIPESTATUS[0]} != 0 ]; then
    # getopt has complained about wrong arguments to stdout
    exit 1
fi
# read getopt's output this way to handle the quoting right
eval set -- "$PARSED"

while true; do
	case "$1" in
		-h|--help)
			print_help
			exit
			;;
		-v|--verbose)
			VERBOSE=1
			shift
			;;
		-d|--database)
			DB="$2"
			shift 2
			;;
		-o|--output)
			OUT="$2"
			shift 2
			;;
		-t|--type)
			TYPE="$2"
			shift 2
			;;
		-t|--time)
			TIME="$2"
			shift 2
			;;
		-s|--start)
			START="$2"
			shift 2
			;;
		-e|--end)
			END="$2"
			shift 2
			;;
		-r|--rra)
			RRA="$2"
			shift 2
			;;
		--height)
			HEIGHT="$2"
			shift 2
			;;
		--min-width)
			MIN_WIDTH="$2"
			shift 2
			;;
		--)
			shift
			break
			;;
		*)
			echo "argument parsing error"
			exit 1
	esac
done


COLORS=(
	"#FF0000"
	"#00FF00"
	"#0000FF"
	"#FFF700"
	"#EF843C"
	"#1F78C1"
	"#A05DA0"
    "#A01DA0"
)

if [[ -v START ]]
then
    echo "Start graph at command line argument ${START}"
else
    START="$(rrdtool first --rraindex ${RRA} ${DB}.rrd)"
    echo "Start graph at start of archive ${START}"
fi
if [[ -v END ]]
then
    echo "Finish graph at command line argument ${END}"
else
    END="$(rrdtool last ${DB}.rrd)"
    echo "Finish graph at end of archive ${END}"
fi

NOW=`date +%s`
if [[ ! START =~ [N] ]]
then
    START=$(bc -l <<< ${START/N/$NOW})
fi
if [[ ! END =~ [N] ]]
then
    END=$(bc -l <<< ${END/N/$NOW})
fi

LSTART=`date +%F\ %T -d @$START`
LEND=`date +%F\ %T -d @$END`

for p in 'A' 'B' 
do
    rrdtool graph \
        panels$p.png \
        --title "Statistics for panels on port $p from $LSTART to $LEND" \
        --watermark "$(date)" \
        --slope-mode \
        --alt-y-grid \
        --rigid \
        --start ${START} --end ${END} \
        --width ${MIN_WIDTH} \
        --height ${HEIGHT} \
        --color CANVAS#181B1F \
        --color BACK#111217 \
        --color FONT#CCCCDC \
        DEF:${p}_nbr=${DB}.rrd:${p}_nbr:AVERAGE \
            VDEF:${p}_nbr_max=${p}_nbr,MAXIMUM \
            VDEF:${p}_nbr_min=${p}_nbr,MINIMUM \
            VDEF:${p}_nbr_avg=${p}_nbr,AVERAGE \
            CDEF:${p}_nbr_norm=${p}_nbr,${p}_nbr_max,/,100,\* \
            CDEF:${p}_nbr_norm_avg=${p}_nbr,POP,${p}_nbr_avg,100,\*,${p}_nbr_max,/ \
            LINE1:${p}_nbr${COLORS[0]}:"nbr\t" \
            GPRINT:${p}_nbr_max:"(max\: %.2lf \g" \
            GPRINT:${p}_nbr_min:"(min\: %.2lf)" \
            COMMENT:"\n" \
        DEF:${p}_temp=${DB}.rrd:${p}_temp:AVERAGE \
            VDEF:${p}_temp_max=${p}_temp,MAXIMUM \
            VDEF:${p}_temp_min=${p}_temp,MINIMUM \
            VDEF:${p}_temp_avg=${p}_temp,AVERAGE \
            CDEF:${p}_temp_norm=${p}_temp,${p}_temp_max,/,100,\* \
            CDEF:${p}_temp_norm_avg=${p}_temp,POP,${p}_temp_avg,100,\*,${p}_temp_max,/ \
            LINE1:${p}_temp${COLORS[1]}:"${p}_temp\t" \
            GPRINT:${p}_temp_max:"(max\: %.2lf \g" \
            GPRINT:${p}_temp_avg:"(avg\:%.2lf)" \
            COMMENT:"\n" \
        DEF:${p}_fps=${DB}.rrd:${p}_fps:AVERAGE \
            VDEF:${p}_fps_max=${p}_fps,MAXIMUM \
            VDEF:${p}_fps_min=${p}_fps,MINIMUM \
            VDEF:${p}_fps_avg=${p}_fps,AVERAGE \
            CDEF:${p}_fps_norm=${p}_fps,${p}_fps_max,/,100,\* \
            CDEF:${p}_fps_norm_avg=${p}_fps,POP,${p}_fps_avg,100,\*,${p}_fps_max,/ \
            LINE1:${p}_fps${COLORS[2]}:"fps\t" \
            GPRINT:${p}_fps_max:"(max\: %.2lf \g" \
            GPRINT:${p}_fps_min:"(min\:%.2lf)" \
            COMMENT:"\n" \
        DEF:${p}_ifc=${DB}.rrd:${p}_ifc:AVERAGE \
            VDEF:${p}_ifc_max=${p}_ifc,MAXIMUM \
            VDEF:${p}_ifc_min=${p}_ifc,MINIMUM \
            VDEF:${p}_ifc_avg=${p}_ifc,AVERAGE \
            CDEF:${p}_ifc_norm=${p}_ifc,${p}_ifc_max,/,100,\* \
            CDEF:${p}_ifc_norm_avg=${p}_ifc,POP,${p}_ifc_avg,100,\*,${p}_ifc_max,/ \
            LINE1:${p}_ifc${COLORS[3]}:"ifc\t" \
            GPRINT:${p}_ifc_max:"(max\: %.2lf \g" \
            GPRINT:${p}_ifc_min:"(min\:%.2lf)" \
            COMMENT:"\n" 

done