import { createBrowserRouter } from "react-router-dom";
import routes from "./routes";

const clientRouter = (props) => createBrowserRouter(routes(props));

export default clientRouter;
