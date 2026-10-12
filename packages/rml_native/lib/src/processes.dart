import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:rml_native/src/bindings.g.dart' as bindings;
import 'package:rml_native/src/native_json.dart';

final class NativeProcess {
  const NativeProcess({required this.pid, required this.path});

  final int pid;
  final String path;
}

List<NativeProcess> findProcesses(String executableName) =>
    using((Arena arena) {
      final Pointer<Char> name = executableName
          .toNativeUtf8(allocator: arena)
          .cast();
      final String json = jsonResult(
        (Pointer<Pointer<Char>> out) => bindings.rml_processes(name, out),
      );
      return <NativeProcess>[
        for (final Object? item in jsonDecode(json) as List<Object?>)
          if (item case {'pid': final int pid, 'path': final String path})
            NativeProcess(pid: pid, path: path),
      ];
    });

void closeProcess(int pid) => checkStatus(bindings.rml_process_close(pid));

void killProcess(int pid) => checkStatus(bindings.rml_process_kill(pid));
