# -*- coding: utf-8 -*-
using Base.Collections

type Node
    board
    selection
end

function get_next_nodes(board)
    nodes_dic = Dict()
    for i=1:size(board,1),j=1:size(board,2)
        (x,y)=(i,j)
        nodes_dic[((x,y),"R")] = Node(exchange(board,(i,j),(i+1,j)),(i+1,j))
        nodes_dic[((x,y),"L")] = Node(exchange(board,(i,j),(i-1,j)),(i-1,j))
        nodes_dic[((x,y),"U")] = Node(exchange(board,(i,j),(i,j-1)),(i,j-1))
        nodes_dic[((x,y),"D")] = Node(exchange(board,(i,j),(i,j+1)),(i,j+1))
    end
    return nodes_dic
end

function exchange(then_board, start, destination)
    x, y = start
    new_x, new_y=destination
    if !(1 <= new_x <= size(then_board,1) && 1 <= new_y <= size(then_board,2))
        return nothing
    end
    startImg = then_board[x,y]
    destImg = then_board[new_x,new_y]
    return [if (x,y)==start destImg elseif (x,y)==destination startImg else then_board[x,y] end 
            for x=1:size(then_board,2),y=1:size(then_board,1)]
end

function create_distance_table(goal)
    table=Dict()
    for i=1:size(goal,1),j=1:size(goal,2)
        table[goal[i,j]] = (i,j)
    end
    return table
end

function distance_to_goal(table, board)
    ans = 0
    for i = 1:size(board,1),j = 1:size(board,2)
        a = table[board[i,j]]
        b = (i,j)
        x = abs(a[1] - b[1])
        y = abs(a[2] - b[2])
        ans += x + y
    end
    return ans * EXCHANGE_RATE
end

function caliculate_cost(operations)
    pair = operations
    cost = 0
    while pair != ()
        if pair[1][1] in "S"
            cost += SELECTION_RATE
        else
            cost += EXCHANGE_RATE
        end
        pair = pair[2]
    end
    return cost
end

function operations_to_list(operations)
    pair = operations
    lst = {}
    while pair != ()
        push!(lst,pair[1])
        pair = pair[2]
    end
    return lst    
end

function encode_answer_format(operations_list)
    selectcount = 0
    changecount = 0
    ans = ""
    word = ""
    for i = 1:length(operations_list)
        if((operations_list[i] == "L") || (operations_list[i] == "R") || (operations_list[i] == "U") || (operations_list[i] == "D"))
            word = *(word,operations_list[i])
            changecount += 1
        else
            ans = *("\r\n",reverse(word),ans)
            ans = *("\r\n",string(changecount),ans)
            ans = *("\r\n",operations_list[i][2:],ans)
            word = ""
            changecount = 0
            selectcount += 1
        end
    end
    ans =*(string(selectcount),ans)
    return ans
end

function solve(sortedImages, splitColumns, splitRows, limit, sel_rate, exc_rate)
	global LIMIT_SELECTION,SELECTION_RATE,EXCHANGE_RATE,distance_table
    LIMIT_SELECTION = limit
    SELECTION_RATE = sel_rate
    EXCHANGE_RATE = exc_rate
    problem = [(i,j) for i = 0:splitRows-1, j = 0:splitColumns-1]
    answer = sortedImages

    distance_table = create_distance_table(answer)
    queue = PriorityQueue{Any,Any}()

    next_nodes = get_next_nodes(problem)
    for key in keys(next_nodes)
        added_operation = (key[2],("S$(key[1][1]-1)$(key[1][2]-1)",()))
        node = next_nodes[key]
        if node.board != nothing
            h_star = distance_to_goal(distance_table,node.board)
            enqueue!(queue,(node,added_operation,1),h_star+SELECTION_RATE+EXCHANGE_RATE)
        end
    end

    checked_nodes = Set()
    min_distance = 999999

    while length(queue) != 0
        looking_node,operations,selection_count = dequeue!(queue)
        g_star = caliculate_cost(operations)
        if looking_node.board == answer
        	println(looking_node.board)
            println(encode_answer_format(operations_to_list(operations)))
            println("cost=$(caliculate_cost(operations))")
            return encode_answer_format(operations_to_list(operations))
        end
        push!(checked_nodes,looking_node)
        next_nodes = get_next_nodes(looking_node.board)
        for key in keys(next_nodes)
            node = next_nodes[key]
            cost = 0
            select = false
            if key[1] != looking_node.selection
                select = true
                cost += SELECTION_RATE
                added_operation = (key[2],("S$(key[1][1]-1)$(key[1][2]-1)",operations))     
            else
                added_operation = (key[2],operations)
            end

            if node.board != nothing && (node in checked_nodes) == false
                h_star = distance_to_goal(distance_table,node.board)
                f_star = h_star + g_star
                if h_star < min_distance
                    min_distance = h_star
                    println(added_operation,"distance =",f_star)
                    if int(h_star) == 0
                        cost = -1000000000
                        println("stop!")
                    end
                end
                if select
                    new_selection_count = selection_count + 1
                else
                   new_selection_count = selection_count
                end
                if new_selection_count <= LIMIT_SELECTION
                    enqueue!(queue,(node,added_operation,new_selection_count),f_star+cost+EXCHANGE_RATE)         

                end
            end
         end       
    end
    println("not found")
    return false

end
