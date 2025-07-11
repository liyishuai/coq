(************************************************************************)
(*         *      The Rocq Prover / The Rocq Development Team           *)
(*  v      *         Copyright INRIA, CNRS and contributors             *)
(* <O___,, * (see version control and CREDITS file for authors & dates) *)
(*   \VV/  **************************************************************)
(*    //   *    This file is distributed under the terms of the         *)
(*         *     GNU Lesser General Public License Version 2.1          *)
(*         *     (see LICENSE file for the text of the license)         *)
(************************************************************************)

(** The basic parts of coqdep are in [Common]. *)

let warn_home_dir =
  let category = CWarnings.CoreCategories.filesystem in
  CWarnings.create ~name:"cannot-locate-home-dir" ~category Pp.str

let coqdep args =
  let open Common in

  ignore (Feedback.(add_feeder (console_feedback_listener Format.err_formatter)));

  (* Initialize coqdep, add files to dependency computation *)
  if CList.is_empty args then Args.usage ();
  let args = Args.parse (Args.make ()) args in
  let v_files = args.Args.files in
  (* We are in makefile hack mode *)
  let make_separator_hack = true in
  let rocqenv, st = init ~make_separator_hack args in
  let lst = Common.State.loadpath st in
  let st = List.fold_left treat_file_command_line st v_files in

  (* XXX: All the code below is just setting loadpaths, refactor to
     Common coq.boot library *)
  (* Add current dir with empty logical path if not set by options above. *)
  (try ignore (Loadpath.find_dir_logpath (Sys.getcwd()))
   with Not_found -> Loadpath.add_norec_dir_import (Loadpath.add_known lst) "." []);
  (* We don't setup any loadpath if the -boot is passed *)
  let () = match rocqenv with
    | Boot -> ()
    | Env env ->
    let corelib = Boot.Env.(corelib env |> Path.to_string) in
    let user_contrib = Boot.Env.(user_contrib env |> Path.to_string) in
    Loadpath.add_rec_dir_import (Loadpath.add_coqlib_known lst) corelib ["Corelib"];
    if Sys.file_exists user_contrib then
      Loadpath.add_rec_dir_no_import (Loadpath.add_coqlib_known lst) user_contrib [];
    let add_dir s = Loadpath.add_rec_dir_no_import (Loadpath.add_coqlib_known lst) s [] in
    List.iter add_dir (Envars.xdg_dirs ~warn:warn_home_dir);
    List.iter add_dir (Envars.coqpath())
  in
  if args.Args.sort then
    sort st
  else
    compute_deps st |> List.iter (Makefile.print_dep Format.std_formatter)

let main args =
  try
    coqdep args
  with exn ->
    Format.eprintf "*** Error: @[%a@]@\n%!" Pp.pp_with (CErrors.print exn);
    exit 1
