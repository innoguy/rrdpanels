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

rrdtool graph \
    panels.png \
    --title "Statistics for panels from $LSTART to $LEND" \
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
     DEF:detected=${DB}.rrd:detected:AVERAGE \
        VDEF:detected_max=detected,MAXIMUM \
        VDEF:detected_min=detected,MINIMUM \
        VDEF:detected_avg=detected,AVERAGE \
        CDEF:detected_norm=detected,detected_max,/,100,\* \
        CDEF:detected_norm_avg=detected,POP,detected_avg,100,\*,detected_max,/ \
        LINE1:detected${COLORS[0]}:"#panels\t" \
        GPRINT:detected_max:"(max\: %.2lf \g" \
        GPRINT:detected_min:"(min\: %.2lf)" \
        COMMENT:"\n" \
    DEF:temp=${DB}.rrd:temp:AVERAGE \
        VDEF:temp_max=temp,MAXIMUM \
        VDEF:temp_min=temp,MINIMUM \
        VDEF:temp_avg=temp,AVERAGE \
        CDEF:temp_norm=temp,temp_max,/,100,\* \
        CDEF:temp_norm_avg=temp,POP,temp_avg,100,\*,temp_max,/ \
        LINE1:temp${COLORS[1]}:"temp\t" \
        LINE0.5:temp_norm_avg${COLORS[1]}:dashes \
        GPRINT:temp_max:"(max\: %.2lf \g" \
        GPRINT:temp_avg:"(avg\:%.2lf)" \
        COMMENT:"\n" \
    DEF:frat=${DB}.rrd:frat:AVERAGE \
        VDEF:frat_max=frat,MAXIMUM \
        VDEF:frat_min=frat,MINIMUM \
        VDEF:frat_avg=frat,AVERAGE \
        CDEF:frat_norm=frat,frat_max,/,100,\* \
        CDEF:frat_norm_avg=frat,POP,frat_avg,100,\*,frat_max,/ \
        LINE1:frat${COLORS[2]}:"fps\t" \
        GPRINT:frat_max:"(max\: %.2lf \g" \
        GPRINT:frat_min:"(min\:%.2lf)" \
        COMMENT:"\n" 