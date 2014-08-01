using Requests
using URIParser

function get_problem(problem_id,to_communication)
     if to_communication
        r = get("http://sp2lc.salesio-sp.ac.jp/procon.php"; query = {"probID" => problem_id })
        
        if r.data == "error"
           println("server error")
           exit()
        else
           return r.data
        end
    else
        r = get(@sprintf("http://localhost/problem/prob%d",int(problem_id)))
        return r.data
    end
end

function encodebody(table)
  pairs = String[]
  for k in keys(table)
    v = table[k]
    key = URIParser.escape(k)
    value = URIParser.escape(string(v))
    push!(pairs, key * "=" * value)
  end
  return join(pairs, "&")
end

function post_answer(answer_string, time, version_string, problem_id,to_communication)
     if to_communication
        #r = post("http://sp2lc.salesio-sp.ac.jp/procon.php"; query = {"answer_string" => answer_string, "time" => time, "version" => version_string, "probID" => problem_id}) 
        println(encodebody({"answer_string" => answer_string, "time" => time, "version" => version_string, "probID" => problem_id}))
        r = post("http://sp2lc.salesio-sp.ac.jp/procon.php"; data=encodebody({"answer_string" => answer_string, "time" => time, "version" => version_string, "probID" => problem_id}))
        println(r)

        if r.data == "error"
           println("server error")
           exit()        

        elseif r.data == "ok"
           println("complate")
        end
        
        println(r.data)
        return r.data
    else
        r = post("http://localhost/SubmitAnswer"; query = {"playerid" => "1", "problemid" => "00", "answer" => answer_string })
        println(r)
        
        return r.text
        
    end
end
