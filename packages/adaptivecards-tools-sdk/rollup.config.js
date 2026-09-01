// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

import * as sourcemapsModule from "rollup-plugin-sourcemaps";
import * as replaceModule from "@rollup/plugin-replace";
import * as nodeResolveModule from "@rollup/plugin-node-resolve";
import * as cjsModule from "@rollup/plugin-commonjs";
import * as typescriptModule from "rollup-plugin-typescript2";
import { createRequire } from "module";
const require = createRequire(import.meta.url);
const pkg = require("./package.json");
import * as jsonModule from "@rollup/plugin-json";
const sourcemaps = sourcemapsModule.default ?? sourcemapsModule;
const replace = replaceModule.default ?? replaceModule;
const nodeResolve = nodeResolveModule.nodeResolve ?? nodeResolveModule.default ?? nodeResolveModule;
const cjs = cjsModule.default ?? cjsModule;
const typescript = typescriptModule.default ?? typescriptModule;
const json = jsonModule.default ?? jsonModule;

export default {
  input: "src/index.ts",
  external: Object.keys(pkg.dependencies),
  output: {
    file: pkg.main,
    format: "cjs",
    sourcemap: true,
    name: "AdaptiveCardsTools",
  },
  preserveSymlinks: false,
  plugins: [
    sourcemaps(),
    replace({
      delimiters: ["", ""],
      // replace dynamic checks with if (false) since this is for
      // browser only. Rollup's dead code elimination will remove
      // any code guarded by if (isNode) { ... }
      "if (isNode)": "if (false)",
      preventAssignment: true,
    }),
    nodeResolve(),
    cjs(),
    typescript({
      useTsconfigDeclarationDir: true,
    }),
    json(),
  ],
};
