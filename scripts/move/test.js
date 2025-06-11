require("dotenv").config();

const cli = require("@aptos-labs/ts-sdk/dist/common/cli/index.js");

async function test() {
  const move = new cli.Move();

  await move.test({
    packageDirectoryPath: "move",
    namedAddresses: {
      message_board_addr: "0xf951a56dfc533b56fd092ae9aeeb2056a353d8a72c4ea76be674e84b9a61a3ec",
    },
  });
}
test();
