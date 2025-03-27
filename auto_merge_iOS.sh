#!/bin/sh
##A-Shell

# 定义文件大小阈值为 3.5 GB (以字节为单位)
SIZE_THRESHOLD=$((3 * 1024 * 1024 * 1024 + 500 * 1024 * 1024))  # 3.5 GB

# 选择源目录
echo "SD CARDを選び"
sleep 1
pickFolder
deletemark SourceDir
bookmark SourceDir

# 选择输出目录
echo "出力Folderを選び"
sleep 1
pickFolder
deletemark DestDir
bookmark DestDir

# 删除源文件？
echo "[ASKING] Do you want to delete source files after processing? (y/n)"
read delete_answer
delete_files=false
if [ "$delete_answer" = "y" ] || [ "$delete_answer" = "Y" ]; then
    delete_files=true
    echo "[Info] Source files will be deleted after processing."
else
    echo "[Info] Source files will be kept after processing."
fi

# 切换到源目录，并打印当前路径以进行调试
cd ~SourceDir || { echo "Cannot change to source directory. Exiting."; exit 1; }
echo "[Info] Current directory: $(pwd)"

echo "[Info] Start merging the files"

# 使用 ls 查找 MP4 文件
sorted_files=$(ls -1 *.MP4 | sort)
total_files=$(echo "$sorted_files" | wc -l)

if [ "$total_files" -eq 0 ]; then
    echo "[ERROR] No MP4 files found in the source directory."
    exit 1
fi

# 初始化变量用于合并
group=""
index=1
last_large_file=""
processed_files=0

# 替换 seq，使用简单的方式生成进度条
generate_progress_bar() {
    local percent=$1
    local total_length=20
    local filled_length=$(( percent * total_length / 100 ))
    local empty_length=$(( total_length - filled_length ))

    printf "["
    for _ in $(seq 1 $filled_length); do printf "#"; done
    for _ in $(seq 1 $empty_length); do printf " "; done
    printf "] (%d%%)\n" "$percent"
}

# 获取文件的日期和时间
get_file_datetime() {
    # 使用 stat 获取文件的修改日期和时间
    stat -f "%Sm" -t "%Y%m%d_%H%M" "$1"
}

# 获取文件大小
get_file_size() {
    # 使用 stat 获取文件大小
    stat -f "%z" "$1"
}

# 合并文件组的函数
merge_group() {
    if [ -n "$group" ]; then
        first_file=$(echo "$group" | awk '{print $1}')
        last_file=$(echo "$group" | awk '{print $NF}')
        datetime=$(get_file_datetime "$first_file")
        group_name="${datetime}_$(basename "$first_file" .MP4)-$(basename "$last_file" .MP4).mp4"
        echo "[Info] Merging group $index into $group_name"
        
        for file in $group; do
            echo "file '$file'" >> list.txt
        done

        ffmpeg -f concat -safe 0 -i list.txt -c copy "~DestDir/$group_name" -hide_banner -loglevel error
        
        # 检查 ffmpeg 是否成功
        if [ $? -eq 0 ]; then
            echo "..........[ DONE ]"
            # 如果选择删除文件，删除源文件
            if [ "$delete_files" = true ]; then
                echo "[Info] Deleting source files for group $group_name"
                rm $group
            fi
        else
            echo "[ERROR] ffmpeg failed to merge group $group_name. Source files kept."
        fi
        
        rm list.txt
        group=""
        last_large_file=""
        index=$((index + 1))
    fi
}

# 处理文件
for file in $sorted_files; do
    file_size=$(get_file_size "$file")
    
    # 检查 file_size 是否为空或者非数值，确保其为数值
    if ! [ "$file_size" -eq "$file_size" ] 2>/dev/null; then
        echo "[ERROR] Invalid file size for $file, skipping..."
        continue
    fi
    
    processed_files=$((processed_files + 1))

    # 显示当前进度
    percent=$(( processed_files * 100 / total_files ))
    generate_progress_bar "$percent"

    # 如果文件大于阈值，将其视为大文件并加入当前组
    if [ "$file_size" -ge "$SIZE_THRESHOLD" ]; then
        echo "处理大文件 $file, 加入当前组"
        group="$group $file"
        last_large_file="$file"

    # 如果文件小于阈值，且前面有大文件，将其加入组并结束该组
    elif [ "$file_size" -lt "$SIZE_THRESHOLD" ] && [ -n "$last_large_file" ]; then
        echo "处理小文件 $file, 加入当前组并结束该组"
        group="$group $file"
        merge_group

    # 否则，将其视为独立小文件
    else
        # 先合并当前组
        if [ -n "$group" ]; then
            merge_group
        fi
        # 处理独立小文件
        datetime=$(get_file_datetime "$file")
        new_name="${datetime}_$(basename "$file" .MP4).mp4"
        if [ "$delete_files" = true ]; then
            echo "[Info] Moving standalone file $file to ~DestDir/$new_name"
            mv "$file" "~DestDir/$new_name"
        else
            echo "[Info] Copying standalone file $file to ~DestDir/$new_name"
            cp "$file" "~DestDir/$new_name"
        fi
        echo "..........[ DONE ]"
    fi
done

# 如果最后有未合并的组，将其合并
if [ -n "$group" ]; then
    merge_group
fi

echo "[Info] Job Completed."