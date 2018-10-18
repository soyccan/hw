#!/bin/sh

init() {
    if [ ! -e table.cache ]; then
        curl 'https://timetable.nctu.edu.tw/?r=main/get_cos_list' --data \
        'm_acy=107&m_sem=1&m_degree=3&m_dep_id=17&m_group=**&m_grade=**&m_class=**&m_option=**&m_crs \
        name=**&m_teaname=**&m_cos_id=**&m_cos_code=**&m_crstime=**&m_crsoutline=**&m_costype=**' > table.cache
    fi
    # $table: formatted as 3 fields: class id \t room \t name
    cat table.cache | egrep -o '"[0-9]+_[0-9]+":{"acy":"107",[^}]+}' | \
        sed -r \
        -e 's/^.*"cos_id":"([0-9]*)".*"cos_time":"([^"]*)".*"cos_ename":"([^"]*)".*$/\1\t\2\t\3/' \
        -e 's/\\r//g' > table
    export table="$(cat table)"

    if [ ! -e mytable ]; then
        for i in $(seq 1 112); do echo 0 >> mytable; done
    fi
    cp mytable mytable.tmp
    # $mytable: a 112-line file (or string) from 1M-7M then 1N-7N ... 1L-7L
    # 112 = 7 * 16
    export mytable="$(cat mytable.tmp)"

    # other flags
    load_options
}

load_options() {
    if [ ! -e options ]; then touch options; fi
    options="$(cat options)"
    echo options=$options
    export show_class_name_room="false"
    export show_extra_time="false"
    for line in $options; do
        echo line=$line
        if [ "$line" = 1 ]; then
            export show_extra_time="true"
        fi
        if [ "$line" = 2 ]; then
            export show_class_name_room='true'
        fi
    done
    echo show_class_name_room=$show_class_name_room, show_extra_time=$show_extra_time
}

print_table() {
    printf 'x |Mon.          |Tue.          |Wed.          |Thu.          |Fri.          |'
    if [ "$show_extra_time" = "true" ]; then
        printf 'Sat.          |Sun.          |'
    fi
    printf '\n'
    printf '  +--------------+--------------+--------------+--------------+--------------+'
    if [ "$show_extra_time" = "true" ]; then
        printf '  ------------+--------------+'
    fi
    printf '\n'
    printf "$1" | awk -v "show_extra_time=$show_extra_time" '''
        BEGIN {
            FS="/"
            letter_idx = 1
            letters_s = "MNABCDXEFGHYIJKL"
            split(letters_s, letters, "")
        }
        {
            if (show_extra_time == "true" \
                || letter_idx == 3  || letter_idx == 4  || letter_idx == 5 \
                || letter_idx == 6  || letter_idx == 8  || letter_idx == 9 \
                || letter_idx == 10 || letter_idx == 11 || letter_idx == 13 \
                || letter_idx == 14 || letter_idx == 15) {

                for (j=0; j<5; j++) {
                    if (j == 0) printf("%c |", letters[letter_idx])
                    else printf ". |"

                    for (i=1; i<=NF; i++) {
                        if (show_extra_time == "true" || i <= 5) {
                            printf("%-14s|", substr($i, 14*j, 14))
                        }
                    }
                    printf "\n"
                }
                printf "--+--------------+--------------+--------------+--------------+--------------+"
                if (show_extra_time == "true") {
                    printf "--------------+--------------+"
                }
                printf "\n"
            }
            letter_idx += 1
        }
    '''
}

get_name_by_id() {
    classid="$1"
    flag="$2" # true or false, whether also get classroom, pass global show_class_name_room at most cases
    printf "$table" | awk -F "\t" -v "flag=$flag" -v "query=$classid" '''
    BEGIN {found=0}
    {
        if ($1 == query && !found) {
            found=1
            if (flag == "true")
                printf $3 "___" $2
            else
                printf $3
        }
    }
    '''
}

generate_classtable_from_id() {
    i=0
    while read classid; do
        # echo classid=$classid
        i=$(( $i + 1 ))
        # if [ "$show_extra_time" = "false" ]; then
        #     if [ "$(( $i % 7 ))" = "6" ] || [ "$(( $i % 7 ))" = "7" ]; then
        #         continue
        #     fi
        # fi

        get_name_by_id "$classid" "$show_class_name_room"

        if [ $(( $i%7 )) = 0 ]; then
            printf '\n'
        else
            printf '/'
        fi
    done < mytable.tmp
    printf '\n'
}

add_class() {
    # ex: $2 = 1010_2G5CD-EC115 or 1174_2IJK-EC220,5CD-EC114
    class=$(echo "$1" | egrep -o "^[0-9]*")
    class_time=$(echo "$1" | sed -r -e "s/^[0-9]+_(.*)/\1/g" \
        -e "s/-[A-Za-z0-9]*//g" \
        -e "s/,//g")
    # class_room=$(echo "$1" | sed -r -e "s/^[0-9]+_(.*)/\1/g" \
    #     -e "s/([0-9][A-Z]+)+-//g")
    add_list=""
    weekday=0
    for i in $(seq 1 ${#class_time}); do
        ch=$(printf $class_time | cut -c $i-$i)
        # echo ch=$ch
        if [ -z "${ch#[0-9]}" ]; then
            # is a number
            weekday=$ch # 1 ~ 7
        else
            if [ $ch = M ]; then time=1; fi
            if [ $ch = N ]; then time=2; fi
            if [ $ch = A ]; then time=3; fi
            if [ $ch = B ]; then time=4; fi
            if [ $ch = C ]; then time=5; fi
            if [ $ch = D ]; then time=6; fi
            if [ $ch = X ]; then time=7; fi
            if [ $ch = E ]; then time=8; fi
            if [ $ch = F ]; then time=9; fi
            if [ $ch = G ]; then time=10; fi
            if [ $ch = H ]; then time=11; fi
            if [ $ch = Y ]; then time=12; fi
            if [ $ch = I ]; then time=13; fi
            if [ $ch = J ]; then time=14; fi
            if [ $ch = K ]; then time=15; fi
            if [ $ch = L ]; then time=16; fi
            index=$(( ($time-1)*7 + $weekday ))
            echo "debug: weekday=$weekday; time=$time; index=$index"
            add_list="$add_list $index"
        fi
    done
    echo "debug: class=$class; class_time=$class_time; add_list=$add_list; add_id=$class"
    printf "$mytable" | awk -v "add_list=$add_list" -v "add_id=$class" '''
    BEGIN {split(add_list, add_arr, " ")}
    {
        to_add = 0
        for (i=1; i<=length(add_arr); i++) {
            if (add_arr[i] == NR) {
                to_add = 1
            }
        }
        if (to_add) {
            if ($0 == "0" || $0 == add_id) {
                print add_id
            }
            else {
                print add_id > "/tmp/conflict"
                print '\n' >> "/tmp/conflict"
                print $0
            }
        }
        else {
            print $0
        }
    }
    ''' > mytable.tmp
    export mytable="$(cat mytable.tmp)"
}

show_table() {
    print_table "$(generate_classtable_from_id)" > /tmp/print_table
    dialog --textbox /tmp/print_table 130 130
}

show_select_class() {
    lst=$(printf "$table" | sed -r -e "s/^([0-9]+)\t(.*)\t(.*)$/\"\1_\2\" \"\3\"/" | tr '\n' ' ')
    # printf "$lst"
    eval "dialog --menu 'Select Class' 30 130 30 $lst" 2> /tmp/classid
}

ask_select() {
    dialog --yesno 'Continue class selecting?\nYES to continue, NO to quit' 30 130
}

ask_save() {
    dialog --yesno 'Save current classtable?' 30 130
}

show_conflict() {
    echo > /tmp/conflict.name
    for line in $(cat /tmp/conflict | sort | uniq); do
        printf "$(get_name_by_id $line true)" >> /tmp/conflict.name
    done
    dialog --msgbox "Class time conflict: $(cat /tmp/conflict.name)" 30 130
}

show_options() {
    if [ "$show_extra_time" = 'true' ]; then
        stat1='on'
    else
        stat1='off'
    fi
    if [ "$show_class_name_room" = 'true' ]; then
        stat2='on'
    else
        stat2='off'
    fi
    dialog --checklist 'Options' 30 130 30 \
        '1' 'Show MNXYL and Sat. and Sun.' "$stat1" \
        '2' 'Show class room' "$stat2" 2> options
}

show_menu() {
    dialog --menu 'Class Management System' 30 130 30 \
        'showtable' 'Show Current Class Table' \
        'addclass' 'Add Class' \
        'options' 'Options' \
        'clear' 'Remove All Class in Current Classtable' \
        'quit' 'Quit' 2> /tmp/menu
}


init
# generate_classtable_from_id > gen # debug

while true; do
    show_menu
    case "$(cat /tmp/menu)" in
        'showtable')
            show_table
        ;;
        'addclass')
            show_select_class
            classid=$(cat /tmp/classid)
            # echo debug: classid=$classid
            add_class $classid
            if [ -e '/tmp/conflict' ]; then
                show_conflict
                rm /tmp/conflict
            fi
        ;;
        'options')
            show_options
            load_options
        ;;
        'clear')
            rm mytable
            rm mytable.tmp
            init
        ;;
        'quit')
            ask_save
            if [ "$?" = 0 ]; then
                cp mytable.tmp mytable
            fi
            break
        ;;
    esac
done

# generate_classtable_from_id
# print_table "$(generate_classtable_from_id)"
# add_class "1166_2G5CD-EC115"
# generate_classtable_from_id
# print_table "$(generate_classtable_from_id)"

# add_class "1174_2IJK-EC220,5CD-EC114"
# generate_classtable_from_id
# echo "$table" | awk '{print $1 "_" $2}' > /tmp/xxx
# while read line; do
#     add_class "$line"
# done < /tmp/xxx

exit 0
