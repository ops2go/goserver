# goserver

Building Backend APIs with Golang
In this section, you will learn how to build backend APIs with Golang. To facilitate your life, you will use Gin, an HTTP web framework written in Golang. Gin is, like many other frameworks, an open-source project that simplifies creating API endpoints.

What is good to keep in mind is that nothing that you will build in this article is impossible to do with the standard library of Golang. The only reason why you are using Gin is because it simplifies and standardizes the process a little, making your life easier.

Creating an In-Memory To-Do List with Golang
Before you start developing your web server, you will start writing the component that will handle the to-do list. To keep things simple, the implementation of this component will consist of a static object that will store all to-do items in-memory. Essentially, this component will work a very simple database (one that does not persist data to disk though).

Typically, this is not a bad way to start out the development process. Implementing a mock version of your database (before implementing your actual database) not only makes testing easier (and something that you can do from the beginning of your project) but it also helps to imply an interface for your store (or database).

Enough said, it's time to get started with your backend API. Golang, by default, will look for packages in the GO_PATH environment variable. This variable usually refers to a place in the user directory (i.e., on Unix-like systems, this would be ~/go, and on Windows, this would be %USERPROFILE%/go).

Packages are then stored in $GO_PATH/src/ and, therefore, placing your projects there will make your life a lot easier. For this tutorial, you can place your Golang project in the ~/go/src/github.com/<YOUR_GITHUB_USER>/golang-angular (you might have to create some of these directories). For the rest of the article, this directory will be referred to as the project root or simply ./.

Note: You will have to replace <YOUR_GITHUB_USER> with your own GitHub username. That is, you do have a GitHub account, right?

So, in your project root (./), create a new directory called todo. Then, inside this directory, create a new file called todo.go with the following code:
```
package todo

import (
    "errors"
    "sync"

    "github.com/rs/xid"
)

var (
    list []Todo
    mtx  sync.RWMutex
    once sync.Once
)

func init() {
    once.Do(initialiseList)
}

func initialiseList() {
    list = []Todo{}
}

// Todo data structure for a task with a description of what to do
type Todo struct {
    ID       string `json:"id"`
    Message  string `json:"message"`
    Complete bool   `json:"complete"`
}

// Get retrieves all elements from the todo list
func Get() []Todo {
    return list
}

// Add will add a new todo based on a message
func Add(message string) string {
    t := newTodo(message)
    mtx.Lock()
    list = append(list, t)
    mtx.Unlock()
    return t.ID
}

// Delete will remove a Todo from the Todo list
func Delete(id string) error {
    location, err := findTodoLocation(id)
    if err != nil {
        return err
    }
    removeElementByLocation(location)
    return nil
}
// Complete will set the complete boolean to true, marking a todo as
// completed
func Complete(id string) error {
    location, err := findTodoLocation(id)
    if err != nil {
        return err
    }
    setTodoCompleteByLocation(location)
    return nil
}

func newTodo(msg string) Todo {
    return Todo{
        ID:       xid.New().String(),
        Message:  msg,
        Complete: false,
    }
}

func findTodoLocation(id string) (int, error) {
    mtx.RLock()
    defer mtx.RUnlock()
    for i, t := range list {
        if isMatchingID(t.ID, id) {
            return i, nil
        }
    }
    return 0, errors.New("could not find todo based on id")
}

func removeElementByLocation(i int) {
    mtx.Lock()
    list = append(list[:i], list[i+1:]...)
    mtx.Unlock()
}

func setTodoCompleteByLocation(location int) {
    mtx.Lock()
    list[location].Complete = true
    mtx.Unlock()
}

func isMatchingID(a string, b string) bool {
    return a == b
}
```
In the very top of the bottom (right after defining the package and importing a few other packages), you will find the variables that will be globally-available in this file:

list: This is the array that will hold all to-do items.
mtx: This is the mutex that will allow you to safely access/manipulate the data in this package across different goroutines.
once: This is a Golang native functionality (sync.Once), which will help you assure that a specific operation will run only once.
After the declaration of these variables, you will find the init function and you will see that it runs another function called initialiseList. The latter is responsible for initializing the array of to-do items but will ensure that this initialization will run only once. As Golang runs the init function whenever the package is initialized (i.e., whenever the package is loaded), you needed to wrap the initialiseList function inside once.Do. In this way, you avoid resetting the array on the runtime.

Then, after these two functions that initialize the package, you will find the Todo structure. This struct defines that to-do items will have an ID, a Message and whether the todo item is Complete or not. Also, while defining this struct, you are also mapping all properties of your struct into its JSON equivalent. This is a very useful feature in Golang and, if needed, you can find more info about it here. As the naming convention in Golang defines that all properties starting with a capital letter are public and all starting with a small letter are private in a struct, this mapping also helps you ensure you can stick with the naming conventions available in JSON.

Note: If you were to define other packages that would use this struct, it would be a good idea to place it in another package for itself. However, for this simple application, placing it here will suffice.

Right after the definition of the Todo struct, you will find the first method of your to-do store: Get. This method starts with a capital letter and, therefore, is public (meaning it can be accessed by other packages). The Get method implementation is very simple, it simply returns your current static to-do list (the global list variable).

Then, below this method, you will find the Add method, which will create a new to-do (based on a user input message) and append to the global list. Notice that you are using your mutex to Lock before you append new items to your list and then Unlock again once the operation ends. As your server might handle multiple operations at the same time, this is a very important step. If these operations try to access the same memory, you can run into a race-condition that might make Golang crash. To avoid this, you are using mutex, which is scoped to your package.

After Add, you will find the last two public functions. First, you will find Delete, which, as the name states, will remove an item from the list. Then, you will find Complete, which will mark a to-do item as complete (based on its ID) in your list.

Then, after the public functions, you will find the private functions of your package. For starter, you will find the newTodo function, which will take in a msg in the form of a string and return a new instance of the Todo struct. This instance will contain an ID (i.e., a UUID in the form of a string) and the complete flag set to false.

The next private function you will find is the findTodoLocation function. You will use this function to find the index location of a to-do item based on its ID. If no matches are found after iterating over all the items, this function will return an error saying that it couldn't find the desired item. Notice that you are using mutex again in this method. This time, you are using the RLock (Read Lock) function since you will only be reading from your list and not writing to it.

Right after the findTodoLocation function, you will see the removeElementByLocation function. In this function, you are setting your list variable to a new array, which contains all elements from the previous list up to a given location, appended with all elements after (but not including) the same given location. This means that, by giving a specific location to this function, you will get a new list without that given location (essentially deleting it from the previous list).

Then, the very last function in your store package is setTodoCompleteByLocation. Just like your remove function, this function takes in a location in the form of an integer. However, this function is much less complex and simply sets the Complete property of the item found on the given location to true.

Lastly, if you take a close look at the source code of this package, you will notice that it is using a third-party package called xid for generating UUIDs (Universally Unique Identifiers). As such, you will need to obtain this package before compiling your application. To do so, you will have to run the following command:

go get github.com/rs/xid
Building the Golang Web Server and Serving Static Files
Right on! Now is the time to develop a web server with Golang and Gin. So, for starters, you will need to grab Gin from the internet. To do this, run the following code:

go get github.com/gin-gonic/gin
Great. Now, in your project root (./), you will create a file called main.go and insert the following code into it:
```
package main

func main() {
    r := gin.Default()
    r.NoRoute(func(c *gin.Context) {
        dir, file := path.Split(c.Request.RequestURI)
        ext := filepath.Ext(file)
        if file == "" || ext == "" {
            c.File("./ui/dist/ui/index.html")
        } else {
            c.File("./ui/dist/ui/" + path.Join(dir, file))
        }
    })

    r.GET("/todo", handlers.GetTodoListHandler)
    r.POST("/todo", handlers.AddTodoHandler)
    r.DELETE("/todo/:id", handlers.DeleteTodoHandler)
    r.PUT("/todo", handlers.CompleteTodoHandler)

    err := r.Run(":3000")
    if err != nil {
        panic(err)
    }
}
```
Compared to the package you built in the last section, this file is pretty straightforward. First, you create your Gin server using gin.Default(). This command will return an object that you can use to configure and run the web server.

Then, you do something that can be considered a little bit hacky. As you may know, routing in Gin is quite specific and cannot have ambiguous routes for the root path. Essentially, Gin will complain if you have a configuration like /* because this will interfere with every other route in your web server (those would never be called). In Node.js (and other popular web servers), you can do this because the path routing is determined by the most specific to the least specific configuration. So, in that case, a route like /api/something would have precedence over /*.

Unfortunately, this is not the case by default in Gin. However, to implement this in your server, you will take advantage of the NoRoute function, which matches all routes that have not been specified already. This route function will assume that this call is asking for a file and attempt to find this file.

If a client asks for the root path, or if the file is not found, you will serve them the index.htmlfile (which will be produced from your Angular project at a later point). Otherwise, you will serve the file requested by the client.

Note: There are other ways to do this and, depending on what you want to achieve, better ways to achieve that. However, for this tutorial, this will do just fine.

Now, after this generic endpoint, you are adding routes to fetch the data from your to-do list. They are all pointing to the same path '/todo', but they all use different HTTP methods:

GET: This endpoint enables users to retrieve the entire to-do list.
POST: This endpoint enables users to add new items to the list.
DELETE: This endpoint enables users to delete a to-do from the list based on an ID.
PUT: This endpoint enables users to change a to-do item from incomplete to complete.
Each one of these endpoints is structured in the same manner (i.e., r.<METHOD>(<PATH>, <Gin function>). Your Gin function is basically any function that takes the parameter of a gin.Context pointer. If you look at the NoRoute function, you will see an example of an anonymous function with the input of a gin.Context pointer.

Lastly, the main.go script runs your web server on port 3000 and panic if an error occurs while running the web server.

In the next section, you will learn how to develop the handlers that will manage the incoming HTTP requests.

Developing the API Endpoints with Gin Handlers
To handle the incoming HTTP requests, in this section, you will learn how to develop Gin handlers. To begin with, you will create a new directory called handlers in the project root. Then, inside this directory, you will create a file called handlers.go. In this file, you will write the code necessary to handle all methods (GET, POST, PUT, and DELETE) available in your API endpoints (/todo).

Since you already implemented most of the functionality necessary in the todo package, this will be a relatively simple exercise. The final code in the handlers.go file will look as such:
```
package handlers

import (
    "encoding/json"
    "io"
    "io/ioutil"
    "net/http"

    "github.com/<YOUR_GITHUB_USER>/golang-auth0-example/todo"
    "github.com/gin-gonic/gin"
)

// GetTodoListHandler returns all current todo items
func GetTodoListHandler(c *gin.Context) {
    c.JSON(http.StatusOK, todo.Get())
}

// AddTodoHandler adds a new todo to the todo list
func AddTodoHandler(c *gin.Context) {
    todoItem, statusCode, err := convertHTTPBodyToTodo(c.Request.Body)
    if err != nil {
        c.JSON(statusCode, err)
        return
    }
    c.JSON(statusCode, gin.H{"id": todo.Add(todoItem.Message)})
}

// DeleteTodoHandler will delete a specified todo based on user http input
func DeleteTodoHandler(c *gin.Context) {
    todoID := c.Param("id")
    if err := todo.Delete(todoID); err != nil {
        c.JSON(http.StatusInternalServerError, err)
        return
    }
    c.JSON(http.StatusOK, "")
}

// CompleteTodoHandler will complete a specified todo based on user http input
func CompleteTodoHandler(c *gin.Context) {
    todoItem, statusCode, err := convertHTTPBodyToTodo(c.Request.Body)
    if err != nil {
        c.JSON(statusCode, err)
        return
    }
    if todo.Complete(todoItem.ID) != nil {
        c.JSON(http.StatusInternalServerError, err)
        return
    }
    c.JSON(http.StatusOK, "")
}

func convertHTTPBodyToTodo(httpBody io.ReadCloser) (todo.Todo, int, error) {
    body, err := ioutil.ReadAll(httpBody)
    if err != nil {
        return todo.Todo{}, http.StatusInternalServerError, err
    }
    defer httpBody.Close()
    return convertJSONBodyToTodo(body)
}

func convertJSONBodyToTodo(jsonBody []byte) (todo.Todo, int, error) {
    var todoItem todo.Todo
    err := json.Unmarshal(jsonBody, &todoItem)
    if err != nil {
        return todo.Todo{}, http.StatusBadRequest, err
    }
    return todoItem, http.StatusOK, nil
}
```
Note: You will have to replace <YOUR_GITHUB_USER> in the code above with your own GitHub username.

As mentioned earlier, all of your handler functions take a pointer to gin.Context as a parameter. This parameter essentially contains the http.Request reader and an http.ResponseWriter writer. Besides these functionalities that allow you to read from the request and to write a response, this pointer contains a lot of metadata about the request.

Basically speaking, this code is structured as follows:

Grab input and convert if necessary.
Check for errors.
Perform operation.
Return error or the ok status.
At the bottom of the code, you will notice two helper functions specifically tailored to parse input. The convertHTTPBodyToTodo function will read the body from the request and return it as a Todo object. This is done by using the ioutil.ReadAll which will read all bytes from an io.Reader stream. Once this function reads all bytes, you use convertJSONBodyToTodo to convert them from JSON (which is the original format of the request body) to a Todo object.

With these convert operations encapsulated in their functions, it's pretty easy to keep your handlers logic simple and neat. The only other thing that might be worth mentioning the usage of the c.JSON function. You are using this function to convert the response into JSON objects before sending them to your users.

After these changes, you are ready to run your Golang API. So, go to your project root and issue the following command:
```
go run main.go
```
This will make your server start listening requests on localhost:3000. To test it, you can then use a command-line tool like curl or a graphical solution like Postman. Using curl, you can test your application like this:

## add a new to-do item
```
curl localhost:3000/todo -d '{"message": "finish writing the article"}'
```
## get all to-do items
```
curl localhost:3000/todo
```
## Running your Golang backend API

Securing the Golang API with Auth0
That's awesome. You now have a Golang backend API up and running. Time to celebrate? Not quite yet... you have one big issue. Right now, anyone can issue requests to your API. That's not ideal. You probably want to make sure that only people that you trust can access and edit your to-do list. To do this, you will use Auth0 as the Identity and Access Management (IAM) system of your service.

If you don't have an Auth0 account yet, you can sign up for a free one here.

After signing up for Auth0, you will have to go to your Auth0 dashboard and proceed as follows:

go to the APIs section;
click on Create API;
define a Name for your API (e.g., "Golang API");
define an Identifier for it (e.g., https://my-golang-api);
and click on the Create button (leave the Signing Algorithm with RS256).
Creating an Auth0 API to represent a Golang backend

In a second or two, Auth0 will redirect you to your new Auth0 API. For this article, you won't have to change any other configuration on Auth0's dashboard. However, you can leave it open as you will have to copy a few values from it soon.

So, back in your code, you will want to refactor your API to check if the requests arriving have access tokens issued by Auth0. To do this, open your main.go file and replace its code with this:
```
package main

import (
    "log"
    "net/http"
    "os"
    "path"
    "path/filepath"

    "github.com/auth0-community/go-auth0"
    "github.com/gin-gonic/gin"
    jose "gopkg.in/square/go-jose.v2"

    "github.com/<YOUR_GITHUB_USER>/golang-auth0-example/handlers"
)

var (
    audience string
    domain   string
)

func main() {
    setAuth0Variables()
    r := gin.Default()

    // This will ensure that the angular files are served correctly
    r.NoRoute(func(c *gin.Context) {
        dir, file := path.Split(c.Request.RequestURI)
        ext := filepath.Ext(file)
        if file == "" || ext == "" {
            c.File("./ui/dist/ui/index.html")
        } else {
            c.File("./ui/dist/ui/" + path.Join(dir, file))
        }
    })

    authorized := r.Group("/")
    authorized.Use(authRequired())
    authorized.GET("/todo", handlers.GetTodoListHandler)
    authorized.POST("/todo", handlers.AddTodoHandler)
    authorized.DELETE("/todo/:id", handlers.DeleteTodoHandler)
    authorized.PUT("/todo", handlers.CompleteTodoHandler)

    err := r.Run(":3000")
    if err != nil {
        panic(err)
    }
}

func setAuth0Variables() {
    audience = os.Getenv("AUTH0_API_IDENTIFIER")
    domain = os.Getenv("AUTH0_DOMAIN")
}

// ValidateRequest will verify that a token received from an http request
// is valid and signyed by Auth0
func authRequired() gin.HandlerFunc {
    return func(c *gin.Context) {

        var auth0Domain = "https://" + domain + "/"
        client := auth0.NewJWKClient(auth0.JWKClientOptions{URI: auth0Domain + ".well-known/jwks.json"}, nil)
        configuration := auth0.NewConfiguration(client, []string{audience}, auth0Domain, jose.RS256)
        validator := auth0.NewValidator(configuration, nil)

        _, err := validator.ValidateRequest(c.Request)

        if err != nil {
            log.Println(err)
            terminateWithError(http.StatusUnauthorized, "token is not valid", c)
            return
        }
        c.Next()
    }
}

func terminateWithError(statusCode int, message string, c *gin.Context) {
    c.JSON(statusCode, gin.H{"error": message})
    c.Abort()
}
```
Note: You will have to replace <YOUR_GITHUB_USER> in the code above with your own GitHub username.

If you analyze the new version of this code carefully, you will notice that you added a routing group (called authorized) to secure all endpoints in your backend. That is, by calling authorized.Use(authRequired()) and putting all endpoint definitions inside the authorized routing group, you are telling Gin that all requests made to these endpoints must be evaluated by the authRequired function first.

Another change in this code is the addition of two new global variables: audience and domain. You need these variables so you can validate access tokens against Auth0. As you can see, these variables will be retrieved from your environment variables on start, using the setAuth0Variables function. You will set them with your Auth0 values before running your backend again.

As the core piece of validation is the authRequired function, a better explanation about it is required. The authRequired function is what is known as a middleware function. In Gin terms, a middleware must return a gin.HandlerFunc function that contains a call to Next() in the body. Basically, your function validates a token, which is found in the Authorization header of the incoming request. The middleware does this by using JWKS (JSON Web Key Set). Essentially, JWKS is a method for verifying JWT, using a public/private key infrastructure.

Luckily for you, using Auth0's Golang library makes this process extremely simple. All you have to do is to write a few lines of code to validate the incoming token. If this results in an error, you terminate the current connection, responding to it with an http.StatusUnauthorized (401) status. If the token is valid, then you send the request onto the next function (by calling Next()) in the handler chain.

Before wrapping up, you still need to install the two new libraries that this code is now using:
```
go get github.com/auth0-community/go-auth0 gopkg.in/square/go-jose.v2
``` 

That's it. Securing a Golang backend API with Auth0 is as simple as that. To see this in action, hit Ctrl + c to stop the previously running instance of your API and then run it again:

# set env variables
```
export AUTH0_API_IDENTIFIER=<YOUR_AUTH0_API>
export AUTH0_DOMAIN=<YOUR_AUTH0_TENANT>.auth0.com

go run main.go
```
Note: You have to replace <YOUR_AUTH0_API> with the identifier you set in your Auth0 API while creating it. Also, you have to replace <YOUR_AUTH0_TENANT> with the subdomain you chose while creating your Auth0 account.

Now, if you try to issue a request to your API without sending an access token retrieved from Auth0:
```
curl GET localhost:3000/todo
```
You will get a nice error sent back:
```
{
  "error":"token is not valid"
}
```
To fetch a temporary access token to validate that your server still works, you can go to the Test section of your Auth0 API and copy the curl command shown there.

Auth0 showing a curl command to generate access tokens.

Executing this curl command will make Auth0 generate an access token that you can use to communicate with your backend API.

Terminal window showing access token generated by Auth0.

To facilitate issuing requests to your backend, you can copy the access token generated and save it in an environment variable:
```
ACCESS_TOKEN="eyJ0eX...WXaTRg"
```
After that, you can issue authenticated requests like this:

# authenticated req to add a new to-do item
```
curl -H 'Authorization: Bearer '$ACCESS_TOKEN localhost:3000/todo -d '{"message": "finish writing the article"}'
```
# authenticated req to get all to-do items
```
curl -H 'Authorization: Bearer '$ACCESS_TOKEN localhost:3000/todo
```

## Conclusion and Next Steps
Done! You just finished developing a secure backend API with Golang, Gin, and Auth0. The application that you created was pretty simple, just a todo list where you can add, delete, and to-do items as complete. However, the framework around your application is quite sound. You handled authentication via Auth0, which creates a very strong starting point for your application (it is important to think about security and identity management from the start).

Adding features to your application now becomes a lot easier. Once you have established a strong fundament in security, you can add different to-do lists for different users. Using a third-party security solution like Auth0 is also a great advantage because you can rest assured that this solution will keep your users' personal data safe. With a few changes here and there (such as serving your API and static files over HTTPS), you can quite confidently deploy this code to production.

I hope the first part of this series has been helpful and that it has given some insight on how easy it is to implement Auth0 as a third-party authentication service on Golang. In the second part of this series, The Front-end - Developing and Securing Angular Apps, you will learn how to implement the frontend client of your to-do list with Angular and how to integrate it with your Golang backend API.