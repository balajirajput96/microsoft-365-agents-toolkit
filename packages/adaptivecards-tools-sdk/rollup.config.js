// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

import sourcemaps from "rollup-plugin-sourcemaps";
import replace from "@rollup/plugin-replace";
import { nodeResolve } from "@rollup/plugin-node-resolve";
import cjs from "@rollup/plugin-commonjs";
import typescript from "rollup-plugin-typescript2";
import { createRequire } from "node:module";
import json from "@rollup/plugin-json";

const require = createRequire(import.meta.url);
const pkg = require("./package.json");

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
