#!/bin/sh

function init() {
    if [ ! -e table.cache ]; then
        curl 'https://timetable.nctu.edu.tw/?r=main/get_cos_list' --data \
        'm_acy=107&m_sem=1&m_degree=3&m_dep_id=17&m_group=**&m_grade=**&m_class=**&m_option=**&m_crs \
        name=**&m_teaname=**&m_cos_id=**&m_cos_code=**&m_crstime=**&m_crsoutline=**&m_costype=**' > table.cache
    fi
    # $table: formatted as 3 fields: class id \t room \t name
    export table=$(cat table.cache | egrep -o '"[0-9]+_[0-9]+":{"acy":"107",[^}]+}' | sed -r \
        -e 's/^.*"cos_id":"([0-9]*)".*"cos_time":"([^"]*)".*"cos_ename":"([^"]*)".*$/\1\t\2\t\3/')

    if [ ! -e mytable ]; then
        for i in {1..112}; do echo 0 >> mytable; done
    fi
    # $mytable: a 112-line file (or string) from 1M-7M then 1N-7N ... 1L-7L
    # 112 = 7 * 16
    export mytable="$(cat mytable)"

    # other flags
    export show_class_name_room='name' # (name|room|nameroom)
    export show_extra_time='true'
}

function print_table() {
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
            letter_idx=1
            if (show_extra_time == "true") {
                letters_s = "MNABCDXEFGHYIJKL"
            }
            else {
                letters_s = "ABCDEFGHIJK"
            }
            split(letters_s, letters, "")
        }
        {
            for (j=0; j<4; j++) {
                if (j == 0) printf("%c |", letters[letter_idx])
                else printf ". |"

                for (i=1; i<=NF; i++) {
                    printf("%-14s|", substr($i, 14*j, 14))
                }
                printf "\n"
            }
            printf "--+--------------+--------------+--------------+--------------+--------------+"
            if (show_extra_time == "true") {
                printf "--------------+--------------+"
            }
            printf "\n"
            letter_idx += 1
        }
    '''
}

function generate_classtable_from_id() {
    i=0
    while read classid; do
        # echo classid=$classid
        i=$(( $i + 1 ))
        if [ "$show_extra_time" = "false" ]; then
            if [ "$(( $i % 7 ))" = "6" ] || [ "$(( $i % 7 ))" = "7" ]; then
                continue
            fi
        fi
        printf "$table" | awk -F "\t" -v "flag=$show_class_name_room" -v "query=$classid" '''
        BEGIN {found=0}
        {
            if ($1 == query && !found) {
                found=1
                if (flag == "name")
                    printf $3
                else if (flag == "room")
                    printf $2
                else if (flag == "nameroom")
                    printf $3 "___" $2
            }
        }
        '''

        if [ $show_extra_time = true ]; then
            weekdays=7
        else
            weekdays=5
        fi

        if [ $(( $i%$weekdays )) == 0 ]; then
            printf '\n'
        else
            printf '/'
        fi
    done < mytable
    printf '/\n'
}

function add_class() {
    # ex: $2 = 1010_2G5CD-EC115 or 1174_2IJK-EC220,5CD-EC114
    class=$(echo "$1" | egrep -o "^[0-9]*")
    class_time=$(echo "$1" | sed -r -e "s/^[0-9]+_(.*)/\1/g" \
        -e "s/-[A-Za-z0-9]*//g" \
        -e "s/,//g")
    # class_room=$(echo "$1" | sed -r -e "s/^[0-9]+_(.*)/\1/g" \
    #     -e "s/([0-9][A-Z]+)+-//g")
    add_list=""
    weekday=0
    for (( i=0; i<${#class_time}; i++ )); do
        ch=${class_time:i:1}
        echo ch=$ch
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
        found = 0
        for (i=1; i<=length(add_arr); i++) {
            if (add_arr[i] == NR) {
                found = 1
                print add_id
            }
        }
        if (!found) print 0
    }
    ''' > mytable.tmp
    export mytable="$(cat mytable.tmp)"
}

init

generate_classtable_from_id
print_table "$(generate_classtable_from_id)"
add_class "1166_2G5CD-EC115"
generate_classtable_from_id
print_table "$(generate_classtable_from_id)"

# add_class "1174_2IJK-EC220,5CD-EC114"
# generate_classtable_from_id
# echo "$table" | awk '{print $1 "_" $2}' > /tmp/xxx
# while read line; do
#     add_class "$line"
# done < /tmp/xxx

echo done
exit 0

1166
1165

"1071_0411": {
                "acy": "107",
                "sem": "1",
                "cos_id": "0411",
                "cos_code": "DAM1367",
                "num_limit": "120",
                "dep_limit": "N",
                "URL": null,
                "cos_cname": "\u5fae\u7a4d\u5206\u7532\uff08\u4e00\uff09",
                "cos_credit": "4.00",
                "cos_hours": "4.00",
                "TURL": "http://jupiter.math.nctu.edu.tw/~smchang/",
                "teacher": "\u5f35\u66f8\u9298",
                "cos_time": "1GH4CD-SA321",
                "memo": "\u5927\u73ed\u6388\u8ab2",
                "cos_ename": "Calculus (I)",
                "brief": "",
                "degree": "3",
                "dep_id": "17",
                "dep_primary": "2",
                "dep_cname": "\u8cc7\u8a0a\u5de5\u7a0b\u5b78\u7cfb",
                "dep_ename": "Department of Computer Science",
                "cos_type": "\u5fc5\u4fee",
                "cos_type_e": "Required",
                "crsoutline_type": "data",
                "reg_num": "120",
                "depType": "U"
            },
