open Format
open Main_act_verifier
open Types
open Cmd
open Deadlock_resolver


(* ------------------- EXCEPTIONS -------------------- *)

exception RuntimeException of string

type prev_state = (LambdaC.t list * ctx)
  

let stateToLambda (lambdas, ctx, _: state): Lambda.t =
  Lambda.assocLeftList (List.map lambdaTaggedToLambda lambdas)

let print_state fmt (lambdas, ctx, _: state) = 
  Format.fprintf fmt "%a\n    %a"
    printCtxLevel ctx
  LambdaTagged.print (LambdaTagged.assocLeftList (lambdas));
  flush stdout

let breakpoint () = ()

let panic str = raise (RuntimeException str)

let close_ch_action (ch: string) action =
    match action with
    | AIn(c, attr) when c = ch -> AIn(c, {attr with is_open = false})
    | AOut(c, attr) when c = ch -> AOut(c, {attr with is_open = false})
    | AClose(c, attr) when c = ch -> AClose(c, {attr with is_open = false})
    | _ -> action

let rec close_ch_lambda (ch: string) (lambda: LambdaTagged.t) =
    match lambda with
    | LNil -> lambda
    | LOrI(a, b) -> LOrI(close_ch_lambda ch a, close_ch_lambda ch b)
    | LOrE(a, b) -> LOrE(close_ch_lambda ch a, close_ch_lambda ch b)
    | LPar(a, b) -> LPar(close_ch_lambda ch a, close_ch_lambda ch b)
    | LList(EEta(a, t), b) -> LList(EEta(close_ch_action ch a, t), close_ch_lambda ch b)
    | LRepl(EEta(a, t), b) -> LRepl(EEta(close_ch_action ch a, t), close_ch_lambda ch b)

let close_ch ((ch, attr): chan): chan = (ch, {attr with is_open = false})
let write_ch ((ch, attr): chan): chan = (ch, {attr with count = attr.count + 1})
let read_ch ((ch, attr): chan): chan = (ch, {attr with count = attr.count - 1})

let update_ch (act: action) ((ch, attr) as channel: chan) =
    match act with
    | AIn(ch', _) when ch = ch' -> read_ch channel
    | AOut(ch', _) when ch = ch' -> write_ch channel
    | AClose(ch', _) when ch = ch' -> close_ch channel
    | _ -> channel

let update_eta (patch: action) (patching: action): action =
    match patching with
    | AIn(ch) -> AIn(update_ch patch ch)
    | AOut(ch) -> AOut(update_ch patch ch)
    | AClose(ch) -> AClose(update_ch patch ch)
    | ACall(a) -> ACall(a)

let rec apply_action (act: action) (lambda: LambdaTagged.t): LambdaTagged.t =
    match lambda with
    | LNil -> lambda
    | LOrI(a, b) -> LOrI(apply_action act a, apply_action act b)
    | LOrE(a, b) -> LOrE(apply_action act a, apply_action act b)
    | LPar(a, b) -> LPar(apply_action act a, apply_action act b)
    | LList(EEta(a, t), b) -> LList(EEta(update_eta act a, t), apply_action act b)
    | LRepl(EEta(a, t), b) -> LRepl(EEta(update_eta act a, t), apply_action act b)

let update_ch_action ((c, attr): chan) (patching: action): action =
    match patching with
    | AIn(c', attr') ->
        if c' = c then AIn(c, attr)
        else AIn(c', attr')
    | AOut(c', attr') ->
        if c' = c then AOut(c, attr)
        else AOut(c', attr')
    | AClose(c', attr') ->
        if c' = c then AClose(c, attr)
        else AClose(c', attr')
    | ACall(a) -> ACall(a)

let rec update_ch_lambda (channel: chan) (lambda: LambdaTagged.t) =
    match lambda with
    | LNil -> lambda
    | LOrI(a, b) -> LOrI(update_ch_lambda channel a, update_ch_lambda channel b)
    | LOrE(a, b) -> LOrE(update_ch_lambda channel a, update_ch_lambda channel b)
    | LPar(a, b) -> LPar(update_ch_lambda channel a, update_ch_lambda channel b)
    | LList(EEta(a, t), b) -> LList(EEta(update_ch_action channel a, t), update_ch_lambda channel b)
    | LRepl(EEta(a, t), b) -> LRepl(EEta(update_ch_action channel a, t), update_ch_lambda channel b)

let rec replace_ch_with ((ch,_) as old_ch: chan) (new_ch: chan) (lambda: LambdaTagged.t): LambdaTagged.t =
    let aux act =
        match act with
        | AIn(ch', _) when ch' = ch -> AIn(new_ch)
        | AOut(ch', _) when ch' = ch -> AOut(new_ch)
        | AClose(ch', _) when ch' = ch -> AClose(new_ch)
        | ACall(fun_name, params) ->
            ACall(fun_name, List.map (fun (ch',attr') -> if ch' = ch then new_ch else ch',attr') params)
        | _ -> act
    in
    match lambda with
    | LNil -> lambda
    | LOrI(a, b) -> LOrI(replace_ch_with old_ch new_ch a, replace_ch_with old_ch new_ch b)
    | LOrE(a, b) -> LOrE(replace_ch_with old_ch new_ch a, replace_ch_with old_ch new_ch b)
    | LPar(a, b) -> LPar(replace_ch_with old_ch new_ch a, replace_ch_with old_ch new_ch b)
    | LList(EEta(a, t), b) -> LList(EEta(aux a, t), replace_ch_with old_ch new_ch b)
    | LRepl(EEta(a, t), b) -> LRepl(EEta(aux a, t), replace_ch_with old_ch new_ch b)

let call_num = ref 0

let rec rename_iterator (fun_name: string) (lambda: LambdaTagged.t): LambdaTagged.t =
    (*
    let aux act =
        match act with
        | AIn(ch, attr) when ch = ("__loop_" ^ fun_name ^ "_") -> AIn(ch ^ (string_of_int !call_num), attr)
        | AOut(ch, attr) when ch = ("__loop_" ^ fun_name ^ "_") -> AOut(ch ^ (string_of_int !call_num), attr)
        | _ -> act
    in
    *)
    match lambda with
    | LNil -> LNil
    | LOrI(a, b) -> LOrI(rename_iterator fun_name a, rename_iterator fun_name b)
    | LOrE(a, b) -> LOrE(rename_iterator fun_name a, rename_iterator fun_name b)
    | LPar(a, b) -> LPar(rename_iterator fun_name a, rename_iterator fun_name b)
    | LList(a, b) -> LList(a, rename_iterator fun_name b)
    | LRepl(a, b) -> LRepl(a, rename_iterator fun_name b)
    (*
    | LList(a, b) -> LList(aux a, rename_iterator fun_name b)
    | LRepl(a, b) -> LRepl(aux a, rename_iterator fun_name b)
    *)

let rec find_proc (procs: func_def list) (fun_name: string): func_def option =
    match procs with
    | [] -> None
    | (fun_def, _, _) as proc :: t ->
        if fun_name = fun_def then Some proc
        else find_proc t fun_name

let rec concat_proc (to_conc: LambdaTagged.t) (proc: LambdaTagged.t): LambdaTagged.t =
    match proc with
    | LNil -> to_conc
    | LOrI(a, b) -> LOrI(concat_proc to_conc a, concat_proc to_conc b)
    | LOrE(a, b) -> LOrE(concat_proc to_conc a, concat_proc to_conc b)
    | LPar(a, b) -> LPar(concat_proc to_conc a, concat_proc to_conc b)
    | LList(a, b) -> LList(a, concat_proc to_conc b)
    | LRepl(a, b) -> LRepl(a, concat_proc to_conc b)

let merge_errors err1 err2 =
    { err1 with
        states = err1.states @ err2.states;
        double_close = err1.double_close @ err2.double_close;
        closed_write = err1.closed_write @ err2.closed_write;
    }

let append_double_close ch ctx errors =
    let error = {channel = ch; ctx = ctx} in
    { errors with double_close = error::errors.double_close }

let append_closed_write ch ctx errors =
    let error = {channel = ch; ctx = ctx} in
    { errors with closed_write = error::errors.closed_write }

let err_map fn err =
    {err with states = List.map fn err.states}

let patch_pending_proc updated_chs proc =
    List.fold_left (fun acc c -> update_ch_lambda c acc) proc updated_chs

let update_channels_state (act: action) (channels: chan list) =
    match act with
    | AOut(c, _ as channel) | AIn(c, _ as channel) | AClose(c, _ as channel) ->
        if not @@ List.exists (fun (c', attr) -> c = c') channels then channel::channels
        else List.map (update_ch act) channels
    | ACall(_) -> panic "update_channels_state: Received ACall"

let rec find_channel ((ch,_) as channel: chan) (channels: chan list): chan option =
    match channels with
    | [] -> None
    | (ch', _) as channel' :: tl ->
        if ch = ch' then Some(channel')
        else find_channel channel tl

let rec lambda_chans (lambda: LambdaTagged.t) (acc: chan list): chan list =
    let extract_ch (act: action): chan option =
        match act with
        | AIn(c) | AOut(c) | AClose(c) -> Some c
        | ACall(_) -> None
    in
    match lambda with
    | LNil -> acc
    | LOrI(a, b) | LOrE(a, b) | LPar(a, b) ->
        let acc = lambda_chans a acc in
        lambda_chans b acc
    | LList(EEta(a, _), b) | LRepl(EEta(a, _), b) ->
        match extract_ch a with
        | None -> lambda_chans b acc
        | Some(ch) ->
            let acc =
                if find_channel ch acc = None then ch::acc
                else acc
            in
            lambda_chans b acc

type sync_mode =
    | NoSync
    | MustSync
    | Sync of action

let eval_sync (procs: func_def list) ((lambdas, ctx, channels): state): errors =
    breakpoint ();
    let rec do_eval_sync (action: sync_mode) ((lambdas, ctx, channels): state) (acc: errors): errors =
        match action, lambdas with
        | Sync(AClose(_)), _ ->
            panic "Channel closing is not an action that needs synchronizing.\nIf this branch ever executes, something went wrong."
        | Sync(AIn(c, attr) as a), [] when not attr.is_open ->
            {acc with states = ([], conc_lvl ctx (actionToString a), channels)::acc.states}
        | Sync(AOut(c, attr)), [] when not attr.is_open ->
            append_closed_write (c, attr) ctx acc
        | _, [] -> acc

        | _, LList(EEta(ACall(fun_name, args), _), b)::tl ->
            let proc = find_proc procs fun_name in
            begin match proc with
            | None -> panic ("Could not find function '" ^ fun_name ^ "'")
            | Some(def_name, params, stmts) ->
                let proc =
                    List.fold_left2 (fun acc arg param ->
                            let ch = find_channel arg channels in
                            begin match ch with
                            | None -> replace_ch_with param arg acc
                            | Some(ch) -> replace_ch_with param ch acc
                            end
                        ) stmts args params
                    (* |> rename_iterator def_name *)
                    |> concat_proc b
                in
                (* call_num := !call_num + 1; *)
                let channels = lambda_chans proc channels in
                do_eval_sync action (proc::tl, ctx, channels) acc
            end

        | _, (LList(EEta(AClose(c, attr), _), _))::_ when not attr.is_open ->
            append_double_close (c, attr) ctx acc
        | MustSync, (LList(EEta(AOut(c, attr) as a, _), b) as l)::tl
        | NoSync, (LList(EEta(AOut(c, attr) as a, _), b) as l)::tl when attr.capacity <> 0 && attr.count <> attr.capacity ->
            let res1 =
                (* We must explicitly record a channel write happened so that we know there was a state change.
                   If we didn't it could be detected as a deadlock.
                   Drawback is that it may cause the same state to be evaluated more than once. *)
                let reduction =
                    (List.map (apply_action a) (b::tl), conc_lvl ctx (actionToString a), update_channels_state a channels)
                in
                let res = do_eval_sync action reduction acc in
                if action = NoSync then
                    {res with states = reduction::res.states}
                else
                    res
            in
            let res2 =
                do_eval_sync action (tl, ctx, channels) acc
                |> err_map (fun (lambdas, ctx, updated_chs) ->
                    let l = patch_pending_proc updated_chs l in
                    (l::lambdas, ctx, updated_chs))
            in
            merge_errors res1 res2

        | MustSync, (LRepl(EEta(AIn(_, attr), _), _))::_ when attr.capacity <> 0 && attr.count <> attr.capacity ->
            panic "MustSync, LRepl(AIn): Most likely we can merge this branch with NoSync, LRepl(AIn)"
        | NoSync, (LRepl(EEta(AIn(c, attr) as a, _), b) as l)::tl when attr.capacity <> 0 && attr.count <> attr.capacity ->
            let ch = List.map (apply_action a) (b::tl) in
            let res =
                do_eval_sync action (tl, ctx, channels) acc
                |> err_map (fun (lambdas, ctx, updated_chs) ->
                    let bl = List.map (patch_pending_proc updated_chs) [b; l] in
                    (bl @ lambdas, ctx, updated_chs))
            in
            {res with states = (ch, conc_lvl ctx (actionToString a), update_channels_state a channels)::res.states}

        | MustSync, (LList(EEta(AIn(c, attr) as a, _), b) as l)::tl
        | NoSync, (LList(EEta(AIn(c, attr) as a, _), b) as l)::tl when attr.capacity <> 0 && attr.count <> 0 ->
            let res1 =
                (* We must explicitly record a channel read happened so that we know there was a state change.
                   If we didn't it could be detected as a deadlock.
                   Drawback is that it may cause the same state to be evaluated more than once. *)
                let reduction =
                    (List.map (apply_action a) (b::tl), conc_lvl ctx (actionToString a), update_channels_state a channels)
                in
                let res = do_eval_sync action reduction acc in
                if action = NoSync then
                    {res with states = reduction::res.states}
                else
                    res
            in
            let res2 =
                do_eval_sync action (tl, ctx, channels) acc
                |> err_map (fun (lambdas, ctx, updated_chs) ->
                    let l = patch_pending_proc updated_chs l in
                    (l::lambdas, ctx, updated_chs))
            in
            merge_errors res1 res2

        | NoSync, (LList(EEta(AClose(c, attr) as a, _), b) as l)::tl ->
            (* We must explicitly record a channel close happened so that we know there was a state change.
               If we didn't it could be detected as a deadlock.
               Drawback is that it may cause the same state to be evaluated more than once. *)
            let reduction =
                (List.map (apply_action a) (b::tl), conc_lvl ctx (actionToString a), update_channels_state a channels)
            in
            let res1 =
                do_eval_sync action reduction acc
            in
            let res2 =
                do_eval_sync action (tl, ctx, channels) acc
                |> err_map (fun (lambdas, ctx, updated_chs) ->
                        let l = patch_pending_proc updated_chs l in
                        (l::lambdas, ctx, updated_chs))
            in
            let merged = merge_errors res1 res2 in
            {merged with states = reduction::merged.states}
        | MustSync, (LList(EEta(AClose(c, attr), _), b))::tl ->
            (* Current (flimsy) hypothesis is that since we cannot have a channel close as a case of a select statement
               we cannot have AClose with a MustSync action.
               If this happens, try doing the same as the MustSync branch for reading from an asynchronous channel
               with count > 0 (the one above). *)
            panic "Received AClose in MustSync"
        | Sync(action), (LList(EEta(AClose(c, attr) as a, _), b) as l)::tl ->
            let res1 =
                do_eval_sync (Sync(update_eta a action)) (List.map (apply_action a) (b::tl), conc_lvl ctx (actionToString a), update_channels_state a channels) acc
            in
            let res2 =
                do_eval_sync (Sync(action)) (tl, ctx, channels) acc
                |> err_map (fun (lambdas, ctx, updated_chs) ->
                        let l = patch_pending_proc updated_chs l in
                        (l::lambdas, ctx, updated_chs))
            in
            merge_errors res1 res2
        | NoSync  , (LList(EEta(a, _), b) as l)::tl
        | MustSync, (LList(EEta(a, _), b) as l)::tl ->
            let res1 =
                if action = NoSync then
                    do_eval_sync NoSync (tl, ctx, channels) acc
                    |> err_map (fun (lambdas, ctx, updated_chs) ->
                            let l = patch_pending_proc updated_chs l in
                            (l::lambdas, ctx, updated_chs))
                else
                    no_errors
            in
            let res2 =
                do_eval_sync (Sync(a)) (tl, ctx, channels) acc
                |> err_map (fun (lambdas, ctx, updated_chs) ->
                        let b = patch_pending_proc updated_chs b in
                        (b::lambdas, ctx, updated_chs))
            in
            merge_errors res1 res2
        | NoSync  , (LRepl(EEta(a, _), b) as l)::tl
        | MustSync, (LRepl(EEta(a, _), b) as l)::tl ->
            let res1 =
                if action = NoSync then
                    do_eval_sync NoSync (tl, ctx, channels) acc
                    |> err_map (fun (lambdas, ctx, updated_chs) ->
                            let l = patch_pending_proc updated_chs l in
                            (l::lambdas, ctx, updated_chs))
                else
                    no_errors
            in
            let res2 =
                do_eval_sync (Sync(a)) (tl, ctx, channels) acc
                |> err_map (fun (lambdas, ctx, updated_chs) ->
                        let bl = List.map (patch_pending_proc updated_chs) [b; l] in
                        (bl @ lambdas, ctx, updated_chs))
            in
            merge_errors res1 res2
        | Sync(action), (LList(EEta(a, _), b) as l)::tl ->
            let res1 =
                begin match action, a with
                | AIn(_, attr), _ when not attr.is_open ->
                    (* found match *)
                    {acc with states = (l::tl, conc_lvl ctx (actionToString action), channels)::acc.states}
                | AIn(c1, attr1), AOut(c2, attr2)
                | AOut(c1, attr1), AIn(c2, attr2) ->
                    if c1 <> c2 then
                        no_errors
                    else if attr1 <> attr2 then
                        panic "eval_sync:Sync,LList: Channel attribute mismatch"
                    else if not attr2.is_open then
                        append_closed_write (c2, attr2) ctx acc
                    else
                        (* found match *)
                        {acc with states = (b::tl, conc_lvl ctx (actionToString a), channels)::acc.states}
                | _ ->
                    no_errors
                end
            in
            let res2 =
                (* Keep searching *)
                do_eval_sync (Sync(action)) (tl, ctx, channels) acc
                |> err_map (fun (lambdas, ctx, updated_chs) ->
                        let l = patch_pending_proc updated_chs l in
                        (l::lambdas, ctx, updated_chs))
            in
            merge_errors res1 res2
        | Sync(action), (LRepl(EEta(a, _), b) as l)::tl ->
            let res1 =
                begin match action, a with
                | AClose(_), _ -> panic "do_eval_sync: received AClose in LRepl"
                | AIn(_, attr), _ when not attr.is_open ->
                    (* TODO: Check if `a` and `action` are complements.
                       We should replicate `l` in this case. *)
                    {acc with states = (l::tl, conc_lvl ctx (actionToString action), channels)::acc.states}
                | AIn(c1, attr1), AOut(c2, attr2)
                | AOut(c1, attr1), AIn(c2, attr2) ->
                    if c1 <> c2 then
                        no_errors
                    else if attr1 <> attr2 then
                        panic "eval_sync:Sync,LRepl: Channel attribute mismatch"
                    else if not attr2.is_open then
                        append_closed_write (c2, attr2) ctx acc
                    else
                        (* found match *)
                        {acc with states = (b::l::tl, conc_lvl ctx (actionToString a), channels)::acc.states}
                | _ ->
                    no_errors
                end
            in
            let res2 =
                (* Keep searching *)
                do_eval_sync (Sync(action)) (tl, ctx, channels) acc
                |> err_map (fun (lambdas, ctx, updated_chs) ->
                        let l = patch_pending_proc updated_chs l in
                        (l::lambdas, ctx, updated_chs))
            in
            merge_errors res1 res2
        | NoSync, LOrI(a, b)::tl ->
            {acc with states = [(a::tl, conc_lvl ctx "+1", channels); (b::tl, conc_lvl ctx "+2", channels)] @ acc.states}
        | Sync(_) , LOrI(a, b)::tl
        | MustSync, LOrI(a, b)::tl -> 
            let res1 = (do_eval_sync action (a::tl, conc_lvl ctx "+1", channels) acc) in
            let res2 = (do_eval_sync action (b::tl, conc_lvl ctx "+2", channels) acc) in
            merge_errors res1 res2
        | NoSync  , (LOrE(a, b) as l)::tl
        | MustSync, (LOrE(a, b) as l)::tl ->
            let res1 =
                if action = NoSync then
                    (* let's reduce each possibility individually *)
                    let res1 =
                        do_eval_sync action ([a], conc_lvl ctx "&1", channels) acc
                        |> err_map (fun (lambdas, ctx, updated_chs) ->
                                let tl = List.map (patch_pending_proc updated_chs) tl in
                                (LambdaTagged.LOrE((LambdaTagged.assocLeftList lambdas), b)::tl, ctx, updated_chs))
                    in
                    let res2 =
                        do_eval_sync action ([b], conc_lvl ctx "&2", channels) acc
                        |> err_map (fun (lambdas, ctx, updated_chs) ->
                                let tl = List.map (patch_pending_proc updated_chs) tl in
                                (LambdaTagged.LOrE(a, (LambdaTagged.assocLeftList lambdas))::tl, ctx, updated_chs))
                    in
                    let res3 =
                        do_eval_sync NoSync (tl, ctx, channels) acc
                        |> err_map (fun (lambdas, ctx, updated_chs) ->
                                let l = patch_pending_proc updated_chs l in
                                (l::lambdas, ctx, updated_chs))
                    in
                    merge_errors res1 (merge_errors res2 res3)
                else
                    (* if we're looking to sync, we won't find it in an external or *)
                    no_errors
            in
            (* let's try to execute on a *)
            let res2 = do_eval_sync MustSync (a::tl, ctx, channels) acc
            in
            (* let's try to execute on b *)
            let res3 = do_eval_sync MustSync (b::tl, ctx, channels) acc
            in
            merge_errors res1 (merge_errors res2 res3)
        | Sync(c), LOrE(a, b)::tl ->
            let res1 =
                do_eval_sync (Sync(c)) ([a], conc_lvl ctx "&1", channels) acc
                |> err_map (fun (lambdas, ctx, updated_chs) ->
                        let tl = List.map (patch_pending_proc updated_chs) tl in
                        (lambdas @ tl, ctx, updated_chs))
            in
            let res2 =
                do_eval_sync (Sync(c)) ([b], conc_lvl ctx "&2", channels) acc
                |> err_map (fun (lambdas, ctx, updated_chs) ->
                        let tl = List.map (patch_pending_proc updated_chs) tl in
                        (lambdas @ tl, ctx, updated_chs))
            in
            merge_errors res1 res2
        | _, LPar(a, b)::tl ->
            do_eval_sync action (a::b::tl, ctx, channels) acc
        | _, LNil::tl ->
            do_eval_sync action (tl, ctx, channels) acc
    in
    do_eval_sync NoSync (lambdas, ctx, List.fold_left (fun acc x -> lambda_chans x acc) channels lambdas) no_errors
    |> err_map (fun ((lambdas, ctx, updated_chs)) -> (List.filter (( <> ) LambdaTagged.LNil) lambdas, ctx, updated_chs))

let is_LNil_or_LRepl (l: LambdaTagged.t) =
    match l with
    | LNil | LRepl(_, _) -> true
    | _ -> false

let rec prev_state_contained_in_state ((ps_lambdas, ctx): prev_state) (lambdas: LambdaCTagged.t list) =
  let rec inner (ps_l: LambdaC.t) (lambdas: LambdaCTagged.t list) =
      match lambdas with
      | [] -> panic "asd"
      | l_hd::l_tl -> 
        if (eta_equals_eta_tagged ps_l l_hd) then
          l_tl
        else
          l_hd::(inner ps_l l_tl)
  in
  match ps_lambdas with
  | [] -> lambdas
  | ps_hd::ps_tl ->
    let l = inner ps_hd lambdas in
      prev_state_contained_in_state (ps_tl, ctx) l

let find_duplicates (lambdas: LambdaCTagged.t list) (prev_states: prev_state list):
    (LambdaTagged.t list * (Lambda.t list * ctx)) list =
    prev_states
    |> List.filter_map (
        fun (((ps, ps_ctx) as prev_state): prev_state): 'a option ->
            try 
                let remaining = prev_state_contained_in_state prev_state lambdas in
                Some( (remaining, (ps, ps_ctx)) )
            with
            | _ -> None
    )
    |> List.map (fun (l1, (l2, ctx)) -> (List.map LambdaCTagged.lambdaCToLambda l1, ((List.map LambdaC.lambdaCToLambda l2), ctx)))

let eval fmt (procs: func_def list) (lambda: LambdaTagged.t): errors = 
    let rec do_eval (states: (state * prev_state list) list) (acc: errors): errors =
        match states with
        | [] -> acc
        | (((lambdas, ctx, _) as state), prev_states)::tl -> 
            fprintf fmt "%a\n" print_state state;
            (* Strip LNil processes *)
            let lambdas = List.map (LambdaTagged.remLNils) lambdas in
            if List.for_all is_LNil_or_LRepl lambdas then
                do_eval tl acc
            else (
                let res = eval_sync procs state in
                let acc = { acc with
                            double_close = res.double_close @ acc.double_close;
                            closed_write = res.closed_write @ acc.closed_write;
                          }
                in
                if res.states = [] then
                    let errors = { acc with states = state::acc.states }
                    in
                    do_eval tl errors
                else (
                    let lambdasC =
                        lambdas
                        |> List.map LambdaTagged.lparToList
                        |> List.flatten
                        |> List.map LambdaTagged.remLNils 
                        |> List.map lambdaTaggedToLambda
                        |> List.map LambdaC.lambdaToLambdaC
                    in
                    let reductions = res.states
                        |> List.map (fun r -> (r, (lambdasC, ctx)::prev_states))
                        |> List.map (
                            fun (((lambdas, ctx, channels) as state, prev_states): (state * prev_state list) ): (state * prev_state list) list -> 
                                let lambdasC =
                                    lambdas
                                    |> List.map LambdaTagged.lparToList
                                    |> List.flatten
                                    |> List.map LambdaTagged.remLNils 
                                    |> List.map LambdaCTagged.lambdaToLambdaC
                                in
                                let dupl = find_duplicates lambdasC prev_states in
                                if dupl = [] then (
                                    [((lambdas, ctx, channels), prev_states)]
                                ) else (
                                    fprintf fmt "%a\n" print_state state;
                                    Format.fprintf fmt "    DUPLICATES: \n";
                                    List.map (
                                        fun (remaining, (common, common_ctx)) ->
                                            Format.fprintf fmt "    %a ; %a -- %s\n"
                                                LambdaTagged.print (LambdaTagged.assocLeftList remaining)
                                                Lambda.print       (Lambda.assocLeftList common)
                                                common_ctx.level;
                                            ((remaining, ctx, channels), prev_states)
                                    ) dupl
                                )
                            ) 
                        |> List.flatten
                    in
                    do_eval (reductions @ tl) acc
                )
            )
    in
    do_eval [(([lambda], {level="1"}, []), [])] no_errors



let main fmt (((procs, exp), deps): (func_def list * LambdaTagged.t) * dependency list): bool * Lambda.t list * Lambda.t (*passed act_ver * deadlocked processes * resolved process*) =
    let exp = LambdaTagged.remLNils exp in
    let procs = List.map (fun (fun_name, params, stmts) -> fun_name, params, LambdaTagged.remLNils stmts) procs in
    (* Process Completeness Verification *)
    let act_ver = main_act_verifier (lambdaTaggedToLambda exp) in
    if false then (
        fprintf fmt "%a\n" LambdaTagged.print exp;
        print_act_ver fmt act_ver;
        (false, [], LNil)
    ) else (
        fprintf fmt "Program:\n";
        List.iter (fun p -> fprintf fmt "\t"; print_proc fmt p) procs;
        fprintf fmt "\n\t%a\n" LambdaTagged.print exp;
        fprintf fmt "\nAnalysis:\n";
        let (go_fixer_fmt, go_fixer_fmt_buffer) = (
            let buffer = (Buffer.create 0) in
            if !patch then (
                (Some(Format.formatter_of_buffer buffer), buffer)
            ) else (
                (None, buffer)
            )
        ) in
        
        (* Ideally, we would just loop until no deadlock is found and discard the intermediary results.
           But the original implementation returns the first set of deadlocks and the fully deadlock
           resolved expression, so here we do the same. *)
        let (errors, resolved) = detect_and_resolve fmt go_fixer_fmt eval procs exp deps in
        
        if errors.double_close <> [] then (
            let err_type = "Double close on channel" in
            List.iter (fun err -> fprintf fmt "%s '%a' in reduction '%s'\n" err_type print_error err err.ctx.level) errors.double_close;
        );
        
        if errors.closed_write <> [] then (
            let err_type = "Write to closed channel" in
            List.iter (fun err -> fprintf fmt "%s '%a' in reduction '%s'\n" err_type print_error err err.ctx.level) errors.closed_write;
        );
        
        if errors.states = [] then (
            fprintf fmt "\nNo deadlocks!\n";
        ) else (
            fprintf fmt "\nDeadlocks:\n";
            List.iter (fun ((lambdas, _, _) as deadlock) -> 
                (* let top_env = lambdas |> Deadlock_resolver_heuristics.get_top_layer |> List.map Deadlock_resolver_heuristics.get_top_eta in
                fprintf fmt "%a | top env: %a\n" print_state deadlock EtaTagged.print_etalist2 top_env; *)
                fprintf fmt "%a\n" print_state deadlock;
            ) errors.states;
        );
        
        let (fully_resolved, _, resolved) = detect_and_resolve_loop go_fixer_fmt eval procs (errors, resolved) deps [] in
        
        if errors.states <> [] then (
            fprintf fmt "%sResolved:\n%a\n" (if fully_resolved then "Fully " else "") LambdaTagged.print resolved
        );
        
        (* Print and execute Go fixer *)
        Option.iter (
            fun go_fixer_fmt ->
                Format.pp_print_flush go_fixer_fmt ();
                Format.fprintf fmt "\n\n";
                Format.fprintf fmt "%s\n\n" (Buffer.contents go_fixer_fmt_buffer);
                Format.pp_print_flush fmt ();
                
                let (pipe_out, pipe_in) = Unix.pipe () in
                Unix.set_close_on_exec pipe_in;
                let pipe_in_channel = Unix.out_channel_of_descr pipe_in in
                let fixerPID = Unix.create_process "GoDDaR_fixer" (Array.of_list ["GoDDaR_fixer"]) pipe_out Unix.stdout Unix.stderr in
                Unix.close pipe_out;
                Stdlib.output_bytes pipe_in_channel (Buffer.to_bytes go_fixer_fmt_buffer);
                Stdlib.close_out pipe_in_channel;
                ignore (Unix.waitpid [] fixerPID)
        ) go_fixer_fmt;
        
        (true, List.map stateToLambda errors.states, lambdaTaggedToLambda resolved)
    )
