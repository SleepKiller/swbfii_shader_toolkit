#pragma once

#include <functional>
#include <iosfwd>
#include <type_traits>
#include <utility>

namespace detail {

template<typename Type, typename = void>
struct Is_com_class : std::false_type {
};

template<typename Type>
struct Is_com_class<Type, std::void_t<decltype(std::declval<Type>().AddRef()),
                                      decltype(std::declval<Type>().Release())>>
   : std::true_type {
};

template<typename Type>
constexpr bool is_com_class_v = Is_com_class<Type>::value;
}

template<typename Class>
class Com_ptr {
public:
   static_assert(detail::is_com_class_v<Class>,
                 "Class does not implement AddRef and Release.");

   using element_type = Class;

   Com_ptr() = default;

   ~Com_ptr()
   {
      if (_pointer) _pointer->Release();
   }

   explicit Com_ptr(Class* from) noexcept
   {
      _pointer = from;
   }

   Com_ptr(std::nullptr_t) = delete;

   Com_ptr(const Com_ptr& other) noexcept
   {
      if (other) {
         other->AddRef();

         _pointer = other.get();
      }
   }

   Com_ptr& operator=(const Com_ptr& other) noexcept
   {
      if (other) {
         other->AddRef();
      }

      reset(other.get());

      return *this;
   }

   Com_ptr(Com_ptr&& other) noexcept
   {
      swap(other);
   }

   Com_ptr& operator=(Com_ptr&& other) noexcept
   {
      swap(other);

      return *this;
   }

   void reset(Class* with) noexcept
   {
      Com_ptr discarded{_pointer};

      _pointer = with;
   }

   void swap(Com_ptr& other) noexcept
   {
      std::swap(this->_pointer, other._pointer);
   }

   [[nodiscard]] Class* release() noexcept
   {
      Class* pointer = nullptr;
      std::swap(pointer, _pointer);

      return pointer;
   }

   Class* get() const noexcept
   {
      return _pointer;
   }

   Class& operator*() const noexcept
   {
      return *_pointer;
   }

   Class* operator->() const noexcept
   {
      return _pointer;
   }

   [[nodiscard]] Class** clear_and_assign() noexcept
   {
      Com_ptr discarded{};
      swap(discarded);

      return &_pointer;
   }

   explicit operator bool() const noexcept
   {
      return (_pointer != nullptr);
   }

private:
   Class* _pointer = nullptr;
};

template<typename Class>
inline void swap(Com_ptr<Class>& left, Com_ptr<Class>& right) noexcept
{
   left.swap(right);
}

template<typename Class>
inline bool operator==(const Com_ptr<Class>& left, const Com_ptr<Class>& right) noexcept
{
   return (left.get() == right.get());
}

template<typename Class>
inline bool operator!=(const Com_ptr<Class>& left, const Com_ptr<Class>& right) noexcept
{
   return (left.get() != right.get());
}

template<typename Class>
inline bool operator==(const Com_ptr<Class>& left, std::nullptr_t) noexcept
{
   return (left.get() == nullptr);
}

template<typename Class>
inline bool operator!=(const Com_ptr<Class>& left, std::nullptr_t) noexcept
{
   return (left.get() != nullptr);
}

template<typename Class>
inline bool operator==(std::nullptr_t, const Com_ptr<Class>& right) noexcept
{
   return (right == nullptr);
}

template<typename Class>
inline bool operator!=(std::nullptr_t, const Com_ptr<Class>& right) noexcept
{
   return (right != nullptr);
}

template<typename Class>
inline bool operator==(const Com_ptr<Class>& left, Class* const right) noexcept
{
   return (left.get() == right);
}

template<typename Class>
inline bool operator!=(const Com_ptr<Class>& left, Class* const right) noexcept
{
   return (left.get() != right);
}

template<typename Class>
inline bool operator==(Class* const left, const Com_ptr<Class>& right) noexcept
{
   return (right == left);
}

template<typename Class>
inline bool operator!=(Class* const left, const Com_ptr<Class>& right) noexcept
{
   return (right != left);
}

template<typename Class, typename Char, typename Traits>
inline auto operator<<(std::basic_ostream<Char, Traits>& ostream,
                       const Com_ptr<Class>& com_ptr) -> std::basic_ostream<Char, Traits>&
{
   return ostream << com_ptr.get();
}

namespace std {
template<typename Class>
struct hash<Com_ptr<Class>> {
   std::size_t operator()(const Com_ptr<Class>& com_ptr) const noexcept
   {
      return std::hash<Class*>{}(com_ptr.get());
   }
};
}
