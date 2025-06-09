require("dotenv").config();

const cli = require("@aptos-labs/ts-sdk/dist/common/cli/index.js");

async function test() {
  const move = new cli.Move();

  await move.test({
    packageDirectoryPath: "move",
    namedAddresses: {
      message_board_addr: "0x2a6c6b97583161fa7f130c062dd2216b882e35546a4b648f0e9769745397405e",
    },
  });
}
test();
