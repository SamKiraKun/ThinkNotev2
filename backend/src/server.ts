import { createApp, resolveServerPort } from "./app";

const app = createApp();
const port = resolveServerPort();

app.listen(port, () => {
  console.log(`Server is running on port ${port}`);
});
