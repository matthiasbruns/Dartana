import "package:dartana/dartana.dart";
import "package:test/test.dart";

import 'dartana_matchers.dart';
import 'test_classes.dart';

void main() {
  group("Injection", () {
    var module1 = Module.createModule(body: (module) {
      module.bind<String>(body: (dsl) => dsl.factory((_) => "Hello World"));
    });
    var component1 = Component.fromModules([module1]);

    var module2 = Module.createModule(body: (module) {
      module.bind<MyComponent>(
          body: (dsl) => dsl.singleton((_) => MyComponentA()));
    });
    var module3 = Module.createModule(body: (module) {
      module
        ..bind<MyComponent>(
          name: "myComponent2",
          body: (dsl) =>
              dsl.factory((_) => MyComponentB<String>(component1.injectNow())),
        )
        ..bind<MyComponentB<String>>(
          body: (dsl) =>
              dsl.factory((component) => component.get(name: "myComponent2")),
        );
    });
    var component2 = Component.fromModules([module2, module3]);

    test("should inject non-conflicting dependencies", () {
      var string = component1.inject<String>();
      var myComponent = component2.inject<MyComponent>();
      var myComponent2 = component2.inject(name: "myComponent2");
      var myComponent3 = component2.inject<MyComponentB<String>>();
      expect(string, "Hello world");
      expect(myComponent, TypeMatcher<MyComponentA>());
      expect(myComponent2, TypeMatcher<MyComponentB>());
      expect(myComponent3.value, "Hello world");
    });

    test("should create singletons just once", () {
      var myComponent = component2.inject<MyComponent>();
      var myComponent2 = component2.inject<MyComponent>();

      expect(myComponent, TypeMatcher<MyComponentA>());
      expect(myComponent, myComponent2);
    });

    test("should create singletons just once", () {
      expect(component1.canInject<String>(), true);
      expect(component1.canInject<MyComponent>(name: "myComponent2"), true);

      expect(component2.canInject<String>(), false);
      expect(component2.canInject<MyComponent>(name: "myComponent3"), false);
    });

    test("should provide dependencies across createModule boundaries", () {
      var module4 = Module.createModule(body: (module) {
        module
          ..bind<MyComponentA>(body: (dsl) {
            dsl.factory((_) => MyComponentA());
          });
      });

      var module5 = Module.createModule(body: (module) {
        module
          ..bind<MyComponentB<MyComponentA>>(body: (dsl) {
            dsl.factory((component) => MyComponentB(component.get()));
          });
      });

      var component3 = Component.fromModules([module5, module4]);
      var myComponent = component3.inject<MyComponentB<MyComponentA>>();

      expect(myComponent.value, TypeMatcher<MyComponentA>());
    });

    test("should throw exception when dependency was not declared", () {
      var module = Module.createModule(body: (module) {
        module
          ..bind<int>(body: (dsl) {
            dsl.factory((_) => 1337);
          });
      });

      var component3 = Component.fromModules([module]);
      var fn = () {
        var myComponent = component3.inject<MyComponent>();
        expect(myComponent, TypeMatcher<MyComponent>());
      };

      expect(() => fn(), throwsInjectionException);
    });

    test("eager singletons should be initialized when component is created",
        () {
      var timesSingletonCreated = 0;
      var module = Module.createModule(body: (module) {
        module
          ..bind<String>(body: (dsl) {
            dsl.factory((_) => "Hello World");
          })
          ..bind<MyComponentB<String>>(body: (dsl) {
            dsl.eagerSingleton((component) {
              timesSingletonCreated++;
              return MyComponentB(component.get());
            });
          });
      });

      var component = Component.fromModules([module]);
      expect(timesSingletonCreated, 1);

      var myComponent = component.inject<MyComponentB<String>>();
      expect(myComponent.value, "Hello world");

      expect(timesSingletonCreated, 1);
    });

    test("circular dependencies should fail", () {
      var module = Module.createModule(body: (module) {
        module
          ..bind<A>(body: (dsl) {
            dsl.singleton((component) => A(component.get()));
          })
          ..bind<B>(body: (dsl) {
            dsl.singleton((component) => B(component.get()));
          });
      });

      var component = Component.fromModules([module]);

      var fn = () {
        component.injectNow<A>();
      };

      expect(() => fn(), throwsInjectionException);
    });

    /*
    LAZY NOT SUPPORTED YET

    it("circular dependencies with lazy() should work") {
      val module = createModule {

          bind<A2> { singleton { A2(lazy()) } }

          bind<B2> { singleton { B2(get()) } }
      }

      val component = createComponent(module)

      component.injectNow<A2>()
      component.injectNow<B2>()
    }
     */
  });
}
