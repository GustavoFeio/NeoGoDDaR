open Types
;;

let parse (s) : func_def list * Types.LambdaTagged.t =
    let lexbuf = Lexing.from_string s in
    try 
        lambdaToLambdaTagged (CCS_Parser.prog CCS_Lexer.read lexbuf)
    with
        | e ->
            print_endline @@ Printexc.to_string e;
            let position = Lexing.lexeme_start_p lexbuf in
            let pos_string = Format.sprintf "lineNum:Char %d:%d" position.pos_lnum (position.pos_cnum - position.pos_bol) in
            Format.printf "%s\n" pos_string;
            failwith pos_string
