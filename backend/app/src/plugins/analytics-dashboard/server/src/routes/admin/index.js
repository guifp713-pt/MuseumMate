export default () => ({
  type: "admin",
  routes: [
    {
      method: "GET",
      path: "/active-entity",
      handler: "controller.activeEntity",
      config: {
        policies: [],
      },
    },
  ],
});