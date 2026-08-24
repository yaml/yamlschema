import {nodeResolve} from '@rollup/plugin-node-resolve';
import terser from '@rollup/plugin-terser';

export default {
  input: 'src/editor/app.js',
  output: {
    file: 'docs/assets/editor/app.js',
    format: 'es',
  },
  plugins: [nodeResolve(), terser()],
};
