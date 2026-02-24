open Types

exception Fail of string

(* (fun_name, stmt list, (local_name, og_name) list) *)
type stack_entry = string * (MiGo_Types.migo_stmt list) * (string * string) list

let debug_fmt = null_fmt

let check_has_been_called call_name stack =
  if (Option.is_some (List.find_opt (fun (name, _, _) -> call_name = name) stack)) then
    raise (Fail (Format.sprintf "Recursive call (%s)" call_name))

let rec rename_param c stack = 
  match stack with
  | (_, _, var_map) :: tl -> (
      let new_c = List.assoc_opt c var_map in
      match new_c with
      | Some(c') -> rename_param c' tl
      | None -> c
    )
  | [] -> c

let rec find_channel c lst =
    match lst with
    | (c', attr)::tl ->
        if c' = c then Some(c', attr)
        else find_channel c tl
    | [] -> None


let rec do_migo_to_ccs migo_defs (stack: stack_entry list) (deps: (dependency list) ref) (channels: chan list): LambdaTagged.t =
    match stack with 
    | [] -> Format.fprintf debug_fmt "No more stack\n"; LNil
    | (fun_name, stmts, var_map)::tl ->
        begin match stmts with
        | [] -> Format.fprintf debug_fmt "No stmts\n"; do_migo_to_ccs migo_defs (tl) deps channels
        | stmt::stmt_tl ->
            begin match stmt with
            | MiGo_Types.Prefix(Close(c, tag)) ->
                let ch = find_channel (rename_param c stack) channels in
                begin match ch with
                | None -> failwith ("Could not find channel " ^ c)
                | Some(ch) ->
                    LList(
                       EEta(AClose(ch), tag),
                       (do_migo_to_ccs migo_defs ((fun_name, stmt_tl, var_map)::tl) deps channels)
                    )
                end
            | MiGo_Types.Prefix(Send(c, tag)) ->
                let ch = find_channel (rename_param c stack) channels in
                begin match ch with
                | None -> failwith ("Could not find channel " ^ c)
                | Some(ch) ->
                    LList(
                        EEta(AOut(ch), tag),
                        (do_migo_to_ccs migo_defs ((fun_name, stmt_tl, var_map)::tl) deps channels)
                    )
                end
            | MiGo_Types.Prefix(Receive(c, tag, dependencies)) ->
                if dependencies <> [] then deps := (tag, dependencies)::!deps;
                let ch = find_channel (rename_param c stack) channels in
                begin match ch with
                | None -> failwith ("Could not find channel " ^ c)
                | Some(ch) ->
                    LList(
                        EEta(AIn(ch), tag),
                        (do_migo_to_ccs migo_defs ((fun_name, stmt_tl, var_map)::tl) deps channels)
                    )
                end
            | MiGo_Types.IfFor(t, f)
            | MiGo_Types.If(t, f) -> 
                LOrI(
                    (do_migo_to_ccs migo_defs ((fun_name, t@stmt_tl, var_map)::tl) deps channels),
                    (do_migo_to_ccs migo_defs ((fun_name, f@stmt_tl, var_map)::tl) deps channels)
                )
            | MiGo_Types.Call(call_name, call_params) -> 
                check_has_been_called call_name stack;
                let MiGo_Types.Def(def_name, def_params, def_stmts) = Hashtbl.find migo_defs call_name in
                let call_var_map = List.combine def_params call_params in
                    do_migo_to_ccs migo_defs ((def_name, def_stmts, call_var_map)::(fun_name, stmt_tl, var_map)::tl) deps channels
            | MiGo_Types.Spawn(call_name, call_params) -> 
                check_has_been_called call_name stack;
                let MiGo_Types.Def(def_name, def_params, def_stmts) = Hashtbl.find migo_defs call_name in
                (* We need to keep the var_map but don't want to return back to other functions,
                   so we remove the statements from the rest of the stack so that when the goroutine ends
                   there is nothing left to execute from its point of view. *)
                let stack_without_stmts = List.map (fun (fun_name, stmts, var_map) -> (fun_name, [], var_map)) stack in
                let call_var_map = List.combine def_params call_params in
                LPar(
                    (do_migo_to_ccs migo_defs ((fun_name, stmt_tl, var_map)::tl)) deps channels,
                    (do_migo_to_ccs migo_defs ((def_name, def_stmts, call_var_map)::stack_without_stmts)) deps channels
                )
            | MiGo_Types.Select(cases) -> 
                let (tau_cases, other_cases) = List.partition (fun (prefix, _) -> prefix = MiGo_Types.Tau) cases in
                let gen_case = List.map (
                    fun (prefix, stmts) -> 
                        do_migo_to_ccs migo_defs ((fun_name, Prefix(prefix)::stmts, var_map)::tl) deps channels
                ) in
                let tau_cases = gen_case tau_cases in
                let other_cases = gen_case other_cases in
                if tau_cases = [] then
                    LambdaTagged.assocLOrEList other_cases
                else
                    LambdaTagged.assocLOrIList ((LambdaTagged.assocLOrEList other_cases)::tau_cases)
                (* Format.sprintf "(%s)" (String.concat " & " other_case_strings)
                |> fun other_case_expr -> 
                if tau_case_strings = [] then (
                  other_case_expr
                ) else (
                  Format.sprintf "(%s)" (String.concat " + " (other_case_expr::tau_case_strings))
                ) *)
            | MiGo_Types.Newchan(ch_id, _, capacity) (* TODO: Check if channel names are unique *) -> 
                let ch = (ch_id, {default_ch_attr with capacity = capacity}) in
                do_migo_to_ccs migo_defs ((fun_name, stmt_tl, (ch_id, ch_id)::var_map)::tl) deps (ch::channels)
            | MiGo_Types.Prefix(Tau) -> 
                do_migo_to_ccs migo_defs ((fun_name, stmt_tl, var_map)::tl) deps channels
            end
        end

let rec append_iterator (eta: EtaTaggedSet.elt) (lambdas: LambdaTagged.t): LambdaTagged.t =
    match lambdas with
    | LNil -> LList(eta, LNil)
    | LOrI(a, b) -> LOrI(append_iterator eta a, append_iterator eta b)
    | LOrE(a, b) -> LOrE(append_iterator eta a, append_iterator eta b)
    | LPar(a, b) -> LPar(append_iterator eta a, b)
    | LList(EEta(a, t), b) -> LList(EEta(a, t), append_iterator eta b)
    | LRepl(EEta(a, t), b) -> LRepl(EEta(a, t), append_iterator eta b)

let rec do_migo_to_ccs' migo_defs ((fun_name, stmts): string * (MiGo_Types.migo_stmt list)) (deps: (dependency list) ref) (channels: chan list): LambdaTagged.t =
    match stmts with
    | [] -> Format.fprintf debug_fmt "No stmts\n"; LNil
    | stmt::stmt_tl ->
        begin match stmt with
        | MiGo_Types.Prefix(Close(c, tag)) ->
            let ch =
                begin match List.find_opt (fun (c', _) -> c' = c) channels with
                | Some(ch) -> ch
                | None -> (c, default_ch_attr)
                end
            in
            LList(
               EEta(AClose(ch), tag),
               (do_migo_to_ccs' migo_defs (fun_name, stmt_tl) deps channels)
            )
        | MiGo_Types.Prefix(Send(c, tag)) ->
            let ch =
                begin match List.find_opt (fun (c', _) -> c' = c) channels with
                | Some(ch) -> ch
                | None -> (c, default_ch_attr)
                end
            in
            LList(
                EEta(AOut(ch), tag),
                (do_migo_to_ccs' migo_defs (fun_name, stmt_tl) deps channels)
            )
        | MiGo_Types.Prefix(Receive(c, tag, dependencies)) ->
            if dependencies <> [] then deps := (tag, dependencies)::!deps;
            let ch =
                begin match List.find_opt (fun (c', _) -> c' = c) channels with
                | Some(ch) -> ch
                | None -> (c, default_ch_attr)
                end
            in
            LList(
                EEta(AIn(ch), tag),
                (do_migo_to_ccs' migo_defs (fun_name, stmt_tl) deps channels)
            )
        | MiGo_Types.IfFor(t, f)
        (* | MiGo_Types.IfFor(t, _) ->
            let ch = ("__loop_" ^ fun_name ^ "_", default_ch_attr) in
            LPar(
                LRepl(
                    EEta(AIn(ch), ""),
                    append_iterator (EEta(AOut(ch), "")) (do_migo_to_ccs' migo_defs (fun_name, t@stmt_tl) deps channels)
                ),
                LList(EEta(AOut(ch), ""), LNil)
            ) *)
        | MiGo_Types.If(t, f) -> 
            LOrI(
                (do_migo_to_ccs' migo_defs (fun_name, t@stmt_tl) deps channels),
                (do_migo_to_ccs' migo_defs (fun_name, f@stmt_tl) deps channels)
            )
        | MiGo_Types.Call(call_name, call_args) -> 
            ignore (Hashtbl.find migo_defs call_name); (* raises Not_found if it doesn't exist *)
            let call_args = 
                List.fold_right (fun c acc ->
                    let ch = List.find_opt (fun (c',attr') -> c' = c) channels in
                    match ch with
                    | Some(ch) -> ch::acc
                    | None -> (c, default_ch_attr)::acc
                ) call_args []
            in
            LList(
                EEta(ACall(call_name, call_args), ""),
                do_migo_to_ccs' migo_defs (fun_name, stmt_tl) deps channels
            )
        | MiGo_Types.Spawn(call_name, call_args) -> 
            ignore (Hashtbl.find migo_defs call_name);
            let call_args = 
                List.fold_right (fun c acc ->
                    let ch = List.find_opt (fun (c',attr') -> c' = c) channels in
                    match ch with
                    | Some(ch) -> ch::acc
                    | None -> (c, default_ch_attr)::acc
                ) call_args []
            in
            LPar(
                do_migo_to_ccs' migo_defs (fun_name, stmt_tl) deps channels,
                LList(EEta(ACall(call_name, call_args), ""), LNil)
            )
        | MiGo_Types.Select(cases) -> 
            let (tau_cases, other_cases) = List.partition (fun (prefix, _) -> prefix = MiGo_Types.Tau) cases in
            let gen_case = List.map (
                fun (prefix, stmts) -> 
                    do_migo_to_ccs' migo_defs (fun_name, Prefix(prefix)::stmts) deps channels
            ) in
            let tau_cases = gen_case tau_cases in
            let other_cases = gen_case other_cases in
            if tau_cases = [] then
                LambdaTagged.assocLOrEList other_cases
            else
                LambdaTagged.assocLOrIList ((LambdaTagged.assocLOrEList other_cases)::tau_cases)
        | MiGo_Types.Newchan(ch_id, _, capacity) (* TODO: Check if channel names are unique *) -> 
            let ch = (ch_id, {default_ch_attr with capacity = capacity}) in
            do_migo_to_ccs' migo_defs (fun_name, stmt_tl) deps (ch::channels)
        | MiGo_Types.Prefix(Tau) -> 
            do_migo_to_ccs' migo_defs (fun_name, stmt_tl) deps channels
        end

let migo_to_ccs (migo_defs: MiGo_Types.migo_def list): ((func_def list * LambdaTagged.t) * dependency list) =
  let migo_def_hashtbl = Hashtbl.create (List.length migo_defs) in
  List.iter (
    fun (MiGo_Types.Def(name, params, stmts) as def) -> (
      Hashtbl.add migo_def_hashtbl name def
    )
  ) migo_defs;
  let main_fun = "main.main" in
  let Def(_, params, stmts) = (
    try
      Hashtbl.find migo_def_hashtbl main_fun
    with
    | Not_found -> failwith "Could not find entrypoint function (main.main) in MiGo"
  ) in
  Hashtbl.remove migo_def_hashtbl main_fun;
  assert (params = []);
  let deps = ref [] in
  (*
  let ccs = do_migo_to_ccs migo_def_hashtbl [("main.main", stmts, [])] deps [] in
  *)
  let main_ccs = do_migo_to_ccs' migo_def_hashtbl (main_fun, stmts) deps [] in
  ((Hashtbl.fold
      (fun _ (MiGo_Types.Def(def_name, params, stmts)) acc ->
          (def_name, List.map (fun p -> (p, default_ch_attr)) params, do_migo_to_ccs' migo_def_hashtbl (def_name, stmts) deps [])::acc)
  migo_def_hashtbl [], main_ccs), !deps)
