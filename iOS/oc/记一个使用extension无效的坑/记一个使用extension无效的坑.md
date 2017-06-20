# 记一个使用 extension 无效的坑

有一段很简单的代码：
``` objectivec
@implementation ViewController
//  UIView+B.h
- (void)viewDidLoad {
    [super viewDidLoad];

    UIButton *btn = [[UIButton alloc] initWithFrame:CGRectMake(50, 50, 50, 100)];
    [btn setBackgroundColor:[UIColor blackColor]];

    [self.view addSubview:btn];

    btn.height = 50;
}
@end
```
重点在于 `btn.height = 50` 这一句。

这是写了一个扩展来实现的：
``` objectivec
//  UIView+B.h
#import <UIKit/UIKit.h>

@interface UIView (B)

@property(nonatomic, assign) float height;

@end
```
``` objectivec
//  UIView+B.m
#import "UIView+B.h"

@implementation UIView (B)

- (void)setHeight:(float)height {
    self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y, self.frame.size.width, height);
}

- (float)height {
    return self.frame.size.height;
}

@end
```
猜猜结果是什么。

正常来说，它会展示出一个黑色的大小为 50 的正方形。
当然如果考虑正常情况，这篇文章就没有任何意义了。

在某种情况下，这个黑色的 button 将完全不可见。

在公司项目的某处，我们的同事写了类似的一行代码，就此发现了这么一个坑的存在。
无独有偶，在大约一周后，某个公司接入公司项目的 SDK 时，发现他们的主页面上的 button 点击事件居然失效了……

#
# 无耻的分割线

附件提供了一个工程，各位可以下载下来跑一跑看一看~~有钱捧个钱场没钱捧个人场~~。

# 分析
## runtime
众所周知， **objective-C 是在 C 上面增加了 runtime 层，以此来实现面向对象的特性**，而扩展(我将其称之为 extension ，它俩其实是一种东西)，则是基于 runtime 为已有的类增加方法的方式。

我们也可以用 extension 对原有的方法进行重写，重写的方法会覆盖原有的方法。
OC 中并没有重载的概念，它执行时查找方法是根据方法名进行查找的，而不会关注参数类型与返回值类型，所以即使参数类型不同，它也并没有办法正确的识别。

在 app 运行时， runtime 会读取所有的 extension ，然后将方法列表接到原有的方法列表的后面，查找方法时则是从后往前查，所以我们总会先找到 extension 中的方法。

> 如果我们在 extension 中重写了原有的方法，即使我们不引入相应的头文件，在执行时依然会执行到重写后的方法。

## 参数类型错误
``` objectivec
// Person.h
#import <Foundation/Foundation.h>

@interface Person : NSObject

- (void)read:(NSString *)str;

@end
```
``` objc
// Person.m
#import "Person.h"

@implementation Person

- (void)read:(NSString *)str {
    NSLog(@"read str: %@", str);
}

@end
```
```objc
// Person+Extension.h
#import <Foundation/Foundation.h>
#import "Person.h"

@interface Person (Extension)

- (void)read:(NSInteger) intValue;

@end
```
```objc
// Person+Extension.m
#import "Person+Extension.h"

@implementation Person (Extension)

- (void)read:(NSInteger)intValue {
    NSLog(@"intValue: %ld", (long)intValue);
}

@end
```
~~不要吐槽我的类命名~~
我们在 extension 中重写了 `read:` 方法，编译的时候会报一个 warning ：
```
ld: warning: instance method 'read:' in category from /.../Person+Extension.o overrides method from class in /.../Person.o
```
但它却是可以编译通过且有效的。
```objc
#import "Person.h"

    Person* person = [[Person alloc] init];
    [person read:@"abcd"]; // intValue: 4311994504
```
我们输出了一串奇怪的数值。~~这是啥？~~

我们来改写一下 `Person+Extension.m` 中的 `read:` 方法
```objc
// Person+Extension.m
#import "Person+Extension.h"

@implementation Person (Extension)

- (void)read:(NSInteger)intValue {
    NSLog(@"intValue: %ld", (long)intValue); // intValue: 4345221264
    void* voids = (void *)intValue;
    NSString* str = (__bridge NSString *)(voids);
    NSLog(@"intValue by string: %@", str); // intValue by string: abcd
}

@end
```
可以看出，我们打印的 `NSInteger` 实际是一个 `NSString` 的引用，而不是真正的 `NSInteger` 。

## 基础程序运行原理
这里要下放到汇编级别说一说。

在程序运行时， CPU 是不会理睬我们所熟知的所谓**类型**的，它看到的永远都只是一个个的二进制数，所有的类型检查都在编译期间，运行时就不管不顾了，传递参数时，使用寄存器将参数存如寄存器，被调函数会从寄存器中取出数据，再根据被调函数签名中声明的类型转义成相应的类型。
> 可以简单的认为，在参数存入寄存器时，是以 `id` 的类型进行传递的，而在被调函数中强制类型转换为我们需要的类型。

所有的类型检查都由编译器来保证，运行时并不会做检查，毕竟 `id` 类型实际上丢失了所有的类型信息，如果传递的是类引用，接收方也是类引用，还可以使用一些方法判断是不是我们需要的类型，如果其中一方或者双方都是诸如 `int` `float` `double` 之类的值类型，我们该怎么判断它原本的类型呢？没有任何办法。

所以在上面 Person 的 case 中，我们实际是把一个 `NSString` 的引用(地址)当作 `NSInteger` 值打印出来了。

## 回到我们的问题

终于讲到正题了。
简单来说，我们在两个 extension 中写了同名的方法 `height`。
> 在 extension 中声明两个同名的方法并不会出现 warning

``` objectivec
// UIView+A.h
#import <UIKit/UIKit.h>

@interface UIView (A)

@property(nonatomic, assign) CGFloat height;

@end
```
``` objectivec
//  UIView+B.h
#import <UIKit/UIKit.h>

@interface UIView (B)

@property(nonatomic, assign) float height;

@end
```
``` objectivec
typedef CGFLOAT_TYPE CGFloat;
#if defined(__LP64__) && __LP64__
# define CGFLOAT_TYPE double
# define CGFLOAT_IS_DOUBLE 1
# define CGFLOAT_MIN DBL_MIN
# define CGFLOAT_MAX DBL_MAX
#else
# define CGFLOAT_TYPE float
# define CGFLOAT_IS_DOUBLE 0
# define CGFLOAT_MIN FLT_MIN
# define CGFLOAT_MAX FLT_MAX
#endif
```
在 64 位环境下， `CGFloat` 实际是 `double` 类型，而 32 位环境下是 `float` 类型。

> 所以在 64 位环境下，这两个方法的参数类型是不同的。

我们在调用的地方引用了 `UIView+B.h` 文件，所以编译时会判断传入的 50 是一个 `CGFloat` 也就是 `double` 类型的数据。
根据前面的一番阐述，我们可以认为，运行的时候调用了 `UIView+A` 里声明的 `float` 类型的属性。

那么在实际运行时，是怎么调用到 `UIView+A` 里去的？

## Extension 同名方法的优先级问题
网上可以查到的一般都是说不确定或者随机，实则不是，它有一个默认的规则——**先进行链接的 extension 中的方法会先加入方法列表，后进行链接的 extension 中的方法会优先得到调用**。

看附件中的工程，在 `Build Parses` -> `Compile Sources` 中， `UIView+B.m` 在 `UIView+A.m` 的前面，而我们在 `ViewController.m` 中引用的是 `UIView+B.h` 文件。
> 所以，我们编译的时候采用的是 `UIView+B.h` 的方法签名，而运行时却调用到了 `UIView+A` 中。

你可以试试将两个文件的位置调换，你会发现问题~~神奇的~~没有了。

那么， `float` 与 `double` 又有怎样的冲突？

## 从 float 与 double 说起
int 类型在内存中的存储很简单，就是简单的补码表示法(不懂补码表示法的请自觉面壁)，这样也有一个问题就是补码可以表示的范围很受限，所以 int 类型表示的数值范围要小很多，而且它也只能表示整数。
那么如果我们需要表示很大的数或者表示一个小数，要怎么办？ float 与 double 类型应运而生。

float 与 double 作为浮点型，其表示方法是科学表示法，在内存中的表现形式就是小数部分+指数部分的表示，这样就可以表示一个很大的数字了，毕竟用指数表示的时候可以选择的范畴就高了许多。
然而这样带来的问题就是，它会损失精度，10000000000000000001 由于太大，用 int 型无法表示，用 float 则会表示成 1.00000E20，最后那个1~~莫名其妙~~没了。
你有一个数字 1.0 ，问它是否与 1.0 相等，您猜怎么着，不一定……
由于精度的关系，它会有一个误差值，称之为极小值，在日常使用 float 或 double 类型时，我们会主观的判断为，当两个 float 或 double 类型的差值大于这个极小值时，就可以认为它们相等。
> 所以不要用 == 对 float / double 类型的数据进行判断
``` objectivec
    float left = 1.0;
    float right = 1.0;
    if (left == right) {
        NSLog(@"these two are equal");
    }
```
有人会说，我试了一下，是可以输出的啊？~~小明滚出去~~
那么下面这样呢？
``` objectivec
float left = 11.23456789;
left /= 10;
float right = 1.123456789;
NSLog(@"%f, %f", left, right);
if (left == right) {
    NSLog(@"these two are equal");
} else {
    NSLog(@"these two are not equal");
}
// 1.123457, 1.123457
// these two are not equal
```
或者这样：
``` objectivec
float left = 1.012345678;
left -= 1.012345678;
NSLog(@"%f", left);
if (left == 0) {
    NSLog(@"It is zero");
} else {
    NSLog(@"It is not zero");
}
// -0.000000 // 注意这里都有 -0 了
// It is not zero
```
请问你是否真的知道那条线在哪里。

### next step
如下的代码，大家可以猜猜会输出什么。
``` objectivec
    double d = 50;
    float f = (float)d;
    float f2 = *((float*)&d);
    NSLog(@"%f, %f", f, f2);
    // 50.000000, 0.000000
```
使用**强制类型转换**将 double 转换为 float 可以获取到正确的值，而将内存存储的东西直接按照 float 类型读出来却是 0 。
究其原因就是内存中存储方式的不同导致的问题，而强制类型转换实质上编译器是做了一些处理的，所以才能获取到正确的值。
> 但是仍然不要从 double 强制类型转换到 float ，当你存储的真的是一个非常大的值的时候， float 一样获取不到正确的值，反过来却是可以的。

## 另外的话
有人可能会抬杠~~小明滚出去~~，这种情况下，我们完全可以全局搜出所有的同名的 extension 方法，然后将其中一个删掉。
> 理论上是如此，但是，如果其中一个写在 别人提供的 SDK 里呢？你根本搜索不到 SDK 里的这个方法，如果你把 SDK 放到最上面以此强制你的 extension 生效，假设两个同名方法的用途一样还好，如果不一样，你覆盖了 SDK 里的实现， SDK 就会出错， SDK 提供商甚至不知道是怎么出现的这种问题。

> 而且，很大可能想不到是怎么出的问题，更别说想到解决方案了……

# 总结
长篇大论~~的废话~~讲完了。
总结一下：
1. 不要使用诸如 `int` `float` `double` 等基本类型，转而使用 `NSInteger` `CGFloat` 等封装类型;
1. 不要用 `==` 对 `float` `double` 类型进行相等判断;
2. 写 extension 的时候不要用别人一样会用的方法名（例如 `height` ）， OC 环境下请添加前缀及一个 _ ——举例： `ex_height` ;
3. 不要尝试用 extension 重写原有的方法，如果你真的有需要，子类化，或者用 `method swizzle` ，起码这样你还有办法调用到原有的方法，用 extension 重写就会复杂很多;
4. 修改所有你能修改的 warning ，说不定它哪天就会是一个坑;
5. 不要相信所有人的编码能力，包括你自己;
6. SDK 里最好不要用 extension ，哪怕你的 extension 是隐藏起来不会被外部调用到;
