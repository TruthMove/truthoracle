require("dotenv").config();

const cli = require("@aptos-labs/ts-sdk/dist/common/cli/index.js");

async function test() {
  const move = new cli.Move();

  await move.test({
    packageDirectoryPath: "move",
    namedAddresses: {
      message_board_addr: "0x5a650d6c0cc0327b3379cb91a2b3fa858c66a272c770a7c784734bfc3cc2999d",
    },
  });
}
test();
